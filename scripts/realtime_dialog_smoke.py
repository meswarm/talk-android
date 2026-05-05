#!/usr/bin/env python3
"""Smoke test for Volcengine Doubao realtime dialogue WebSocket API.

This intentionally avoids the Android SDK and third-party Python packages so it
can isolate service credentials and realtime protocol behavior.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import random
import socket
import ssl
import struct
import sys
import time
import uuid
import wave
from dataclasses import dataclass
from typing import Any


HOST = "openspeech.bytedance.com"
PATH = "/api/v3/realtime/dialogue"
URL = f"wss://{HOST}{PATH}"
FIXED_APP_KEY = "PlgvMymc7f3tQnJ6"

class HandshakeError(RuntimeError):
    pass


EVENT_NAMES = {
    1: "StartConnection",
    2: "FinishConnection",
    50: "ConnectionStarted",
    51: "ConnectionFailed",
    52: "ConnectionFinished",
    100: "StartSession",
    102: "FinishSession",
    150: "SessionStarted",
    152: "SessionFinished",
    153: "SessionFailed",
    300: "SayHello",
    501: "ChatTextQuery",
    502: "ChatRAGText",
    351: "TTSSentenceEnd",
    352: "TTSResponse",
    359: "TTSEnded",
    451: "ASRResponse",
    459: "ASREnded",
    550: "ChatResponse",
    553: "ChatTextQueryConfirmed",
    559: "ChatEnded",
}


@dataclass
class RealtimeFrame:
    message_type: int
    flags: int
    serialization: int
    compression: int
    event: int | None
    session_id: str | None
    payload: bytes
    code: int | None = None

    @property
    def event_name(self) -> str:
        if self.event is None:
            return "unknown"
        return EVENT_NAMES.get(self.event, str(self.event))

    @property
    def json_payload(self) -> Any:
        if self.serialization != 1 or not self.payload:
            return None
        return json.loads(self.payload.decode("utf-8"))


def _json_bytes(payload: Any) -> bytes:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def _i32(value: int) -> bytes:
    return int(value).to_bytes(4, "big", signed=True)


def build_event_frame(event: int, payload: Any, *, session_id: str | None = None) -> bytes:
    payload_bytes = _json_bytes(payload)
    frame = bytearray([0x11, 0x14, 0x10, 0x00])
    frame += _i32(event)
    if session_id is not None:
        session_bytes = session_id.encode("utf-8")
        frame += _i32(len(session_bytes))
        frame += session_bytes
    frame += _i32(len(payload_bytes))
    frame += payload_bytes
    return bytes(frame)


def parse_realtime_frame(data: bytes) -> RealtimeFrame:
    if len(data) < 8:
        raise ValueError(f"Realtime frame too short: {len(data)} bytes")
    header_size = data[0] & 0x0F
    index = header_size * 4
    message_type = data[1] >> 4
    flags = data[1] & 0x0F
    serialization = data[2] >> 4
    compression = data[2] & 0x0F
    event = None
    code = None
    session_id = None

    if message_type == 0xF:
        code = int.from_bytes(data[index:index + 4], "big", signed=True)
        index += 4
    elif flags == 0x4:
        event = int.from_bytes(data[index:index + 4], "big", signed=True)
        index += 4
        if event >= 100:
            session_id_size = int.from_bytes(data[index:index + 4], "big", signed=True)
            index += 4
            session_id = data[index:index + session_id_size].decode("utf-8")
            index += session_id_size
    elif flags in (0x1, 0x3):
        index += 4

    payload_size = int.from_bytes(data[index:index + 4], "big", signed=True)
    index += 4
    payload = data[index:index + payload_size]
    return RealtimeFrame(
        message_type=message_type,
        flags=flags,
        serialization=serialization,
        compression=compression,
        event=event,
        session_id=session_id,
        payload=payload,
        code=code,
    )


class RawWebSocket:
    def __init__(self, host: str, path: str, headers: dict[str, str], timeout: float) -> None:
        self.host = host
        self.path = path
        self.headers = headers
        self.timeout = timeout
        self.sock: ssl.SSLSocket | None = None
        self.response_headers: dict[str, str] = {}

    def connect(self) -> None:
        raw = socket.create_connection((self.host, 443), timeout=self.timeout)
        sock = ssl.create_default_context().wrap_socket(raw, server_hostname=self.host)
        sock.settimeout(self.timeout)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        lines = [
            f"GET {self.path} HTTP/1.1",
            f"Host: {self.host}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            f"Sec-WebSocket-Key: {key}",
            "Sec-WebSocket-Version: 13",
        ]
        lines += [f"{name}: {value}" for name, value in self.headers.items()]
        request = "\r\n".join(lines) + "\r\n\r\n"
        sock.sendall(request.encode("utf-8"))
        response = self._recv_until_header_end(sock)
        status, headers = self._parse_handshake_response(response)
        if not status.startswith("HTTP/1.1 101") and not status.startswith("HTTP/1.0 101"):
            raise HandshakeError(
                f"WebSocket handshake failed: {status}\n{response.decode('utf-8', 'replace')}",
            )
        self.response_headers = headers
        self.sock = sock

    def send_binary(self, payload: bytes) -> None:
        sock = self._sock()
        mask_key = os.urandom(4)
        header = bytearray([0x82])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length <= 0xFFFF:
            header.append(0x80 | 126)
            header += struct.pack("!H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack("!Q", length)
        masked = bytes(byte ^ mask_key[index % 4] for index, byte in enumerate(payload))
        sock.sendall(bytes(header) + mask_key + masked)

    def recv_binary(self) -> bytes | None:
        sock = self._sock()
        while True:
            first = self._recv_exact(2)
            opcode = first[0] & 0x0F
            masked = bool(first[1] & 0x80)
            length = first[1] & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask_key = self._recv_exact(4) if masked else b""
            payload = self._recv_exact(length)
            if masked:
                payload = bytes(byte ^ mask_key[index % 4] for index, byte in enumerate(payload))
            if opcode == 0x2:
                return payload
            if opcode == 0x1:
                return payload
            if opcode == 0x8:
                return None
            if opcode == 0x9:
                self._send_control(0xA, payload)

    def close(self) -> None:
        if self.sock is None:
            return
        try:
            self._send_control(0x8, b"")
        finally:
            self.sock.close()
            self.sock = None

    def _send_control(self, opcode: int, payload: bytes) -> None:
        sock = self._sock()
        mask_key = os.urandom(4)
        masked = bytes(byte ^ mask_key[index % 4] for index, byte in enumerate(payload))
        sock.sendall(bytes([0x80 | opcode, 0x80 | len(payload)]) + mask_key + masked)

    def _sock(self) -> ssl.SSLSocket:
        if self.sock is None:
            raise RuntimeError("WebSocket is not connected")
        return self.sock

    def _recv_exact(self, size: int) -> bytes:
        sock = self._sock()
        chunks = bytearray()
        while len(chunks) < size:
            chunk = sock.recv(size - len(chunks))
            if not chunk:
                raise EOFError("WebSocket closed")
            chunks += chunk
        return bytes(chunks)

    @staticmethod
    def _recv_until_header_end(sock: ssl.SSLSocket) -> bytes:
        data = bytearray()
        while b"\r\n\r\n" not in data:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
        return bytes(data)

    @staticmethod
    def _parse_handshake_response(response: bytes) -> tuple[str, dict[str, str]]:
        text = response.decode("iso-8859-1", "replace")
        lines = text.split("\r\n")
        headers: dict[str, str] = {}
        for line in lines[1:]:
            if ":" in line:
                name, value = line.split(":", 1)
                headers[name.strip().lower()] = value.strip()
        return lines[0], headers


def run_smoke_test(args: argparse.Namespace) -> int:
    api_key = args.api_key or os.getenv("VOLC_API_KEY")
    app_id = args.app_id or os.getenv("VOLC_APP_ID")
    access_key = args.access_key or os.getenv("VOLC_ACCESS_KEY") or os.getenv("VOLC_ACCESS_TOKEN")
    app_key = args.app_key or os.getenv("VOLC_APP_KEY") or FIXED_APP_KEY
    if not api_key and (not app_id or not access_key):
        print(
            "missing credentials: provide --api-key, or provide --app-id and --access-key",
            file=sys.stderr,
        )
        return 2

    connect_id = args.connect_id or str(uuid.uuid4())
    session_id = args.session_id or str(uuid.uuid4())
    headers = {"X-Api-Resource-Id": args.resource_id, "X-Api-Connect-Id": connect_id}
    if api_key:
        headers["X-Api-Key"] = api_key
    else:
        headers.update(
            {
                "X-Api-App-ID": app_id,
                "X-Api-Access-Key": access_key,
                "X-Api-App-Key": app_key,
            },
        )
    ws = RawWebSocket(HOST, PATH, headers, args.timeout)
    audio = bytearray()
    saw_session_started = False
    saw_tts_audio = False

    print(f"connect {URL}")
    print(f"connect_id={connect_id}")
    print(f"session_id={session_id}")
    try:
        try:
            ws.connect()
        except HandshakeError as error:
            print(error, file=sys.stderr)
            return 1
        logid = ws.response_headers.get("x-tt-logid")
        if logid:
            print(f"x-tt-logid={logid}")
        send_event(ws, 1, {})
        wait_for_events(ws, {50}, args.timeout, audio)

        payload: dict[str, Any] = {
            "dialog": {
                "bot_name": args.bot_name,
                "extra": {"model": args.model},
            },
            "tts": {
                "audio_config": {
                    "format": "pcm_s16le",
                    "sample_rate": 24000,
                    "channel": 1,
                },
            },
        }
        if args.speaker:
            payload["tts"]["speaker"] = args.speaker
        send_event(ws, 100, payload, session_id=session_id)
        saw_session_started = wait_for_events(ws, {150}, args.timeout, audio)

        trigger_event, trigger_payload = build_trigger_event(
            args.mode,
            content=args.content,
            rag_title=args.rag_title,
        )
        trigger_started = time.monotonic()
        first_audio_at: float | None = None
        send_event(ws, trigger_event, trigger_payload, session_id=session_id)
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            data = ws.recv_binary()
            if data is None:
                break
            frame = parse_realtime_frame(data)
            print_frame(frame)
            if frame.event == 352:
                if first_audio_at is None:
                    first_audio_at = time.monotonic()
                audio += frame.payload
                saw_tts_audio = True
            if frame.event == 359:
                break
            if frame.message_type == 0xF or frame.event in (51, 153):
                break

        send_event(ws, 102, {}, session_id=session_id)
        send_event(ws, 2, {})
    finally:
        ws.close()

    if first_audio_at is not None:
        print(f"first_tts_audio_ms={int((first_audio_at - trigger_started) * 1000)}")
    print(f"trigger_total_ms={int((time.monotonic() - trigger_started) * 1000)}")
    if audio:
        write_wav(args.output, audio, sample_rate=24000, channels=1, sample_width=2)
        print(f"wrote {args.output} ({len(audio)} pcm bytes)")
    else:
        print("no TTS audio payload received")
    return 0 if saw_session_started and saw_tts_audio else 1


def build_trigger_event(mode: str, *, content: str, rag_title: str) -> tuple[int, dict[str, Any]]:
    if mode == "say_hello":
        return 300, {"content": content}
    if mode == "chat_text":
        return 501, {"content": content}
    if mode == "chat_rag":
        external_rag = json.dumps(
            [{"title": rag_title, "content": content}],
            ensure_ascii=False,
            separators=(",", ":"),
        )
        return 502, {"external_rag": external_rag}
    raise ValueError(f"unsupported mode: {mode}")


def send_event(ws: RawWebSocket, event: int, payload: Any, *, session_id: str | None = None) -> None:
    print(f"> {EVENT_NAMES.get(event, event)} {json.dumps(payload, ensure_ascii=False, separators=(',', ':'))}")
    ws.send_binary(build_event_frame(event, payload, session_id=session_id))


def wait_for_events(ws: RawWebSocket, targets: set[int], timeout: float, audio: bytearray) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        data = ws.recv_binary()
        if data is None:
            return False
        frame = parse_realtime_frame(data)
        print_frame(frame)
        if frame.event == 352:
            audio += frame.payload
        if frame.event in targets:
            return True
        if frame.message_type == 0xF or frame.event in (51, 153):
            return False
    return False


def print_frame(frame: RealtimeFrame) -> None:
    if frame.serialization == 1:
        payload = frame.payload.decode("utf-8", "replace")
    else:
        payload = f"<{len(frame.payload)} bytes>"
    prefix = f"< {frame.event_name}"
    if frame.code is not None:
        prefix += f" code={frame.code}"
    print(f"{prefix} type={frame.message_type} flags={frame.flags} payload={payload}")


def write_wav(path: str, pcm: bytes, *, sample_rate: int, channels: int, sample_width: int) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with wave.open(path, "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(sample_width)
        wav.setframerate(sample_rate)
        wav.writeframes(pcm)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Test Doubao realtime dialogue without Android SDK")
    parser.add_argument("--app-id", help="X-Api-App-ID; or VOLC_APP_ID")
    parser.add_argument("--access-key", help="X-Api-Access-Key / Access Token; or VOLC_ACCESS_KEY")
    parser.add_argument("--api-key", help="Try newer X-Api-Key auth; or VOLC_API_KEY")
    parser.add_argument("--app-key", default=None, help=f"X-Api-App-Key; default {FIXED_APP_KEY}")
    parser.add_argument("--resource-id", default="volc.speech.dialog")
    parser.add_argument("--connect-id")
    parser.add_argument("--session-id")
    parser.add_argument("--bot-name", default="小智")
    parser.add_argument("--model", default="1.2.1.1", help="1.2.1.1 for O2.0, 2.2.0.0 for SC2.0")
    parser.add_argument("--speaker", default="zh_female_vv_jupiter_bigtts")
    parser.add_argument(
        "--mode",
        choices=("say_hello", "chat_text", "chat_rag"),
        default="say_hello",
        help="Trigger event to test after StartSession",
    )
    parser.add_argument(
        "--content",
        default=(
            "实时语音秘书测试。"
        ),
        help="Text for SayHello/ChatTextQuery, or external RAG content for ChatRAGText",
    )
    parser.add_argument("--say-hello", dest="content", help=argparse.SUPPRESS)
    parser.add_argument("--rag-title", default="消息内容")
    parser.add_argument("--output", default="build/realtime_dialog_smoke/say_hello.wav")
    parser.add_argument("--timeout", type=float, default=20)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    return run_smoke_test(parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
