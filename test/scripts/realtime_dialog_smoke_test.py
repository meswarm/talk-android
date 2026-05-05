import json
import unittest

from scripts import realtime_dialog_smoke


class RealtimeDialogFrameTest(unittest.TestCase):
    def test_start_connection_frame_matches_doc_example(self):
        frame = realtime_dialog_smoke.build_event_frame(1, {})

        self.assertEqual(frame, bytes([17, 20, 16, 0, 0, 0, 0, 1, 0, 0, 0, 2, 123, 125]))

    def test_start_session_frame_matches_doc_example(self):
        session_id = "75a6126e-427f-49a1-a2c1-621143cb9db3"
        payload = {"dialog": {"bot_name": "豆包", "dialog_id": "", "extra": None}}

        frame = realtime_dialog_smoke.build_event_frame(100, payload, session_id=session_id)

        expected = bytes([
            17, 20, 16, 0, 0, 0, 0, 100, 0, 0, 0, 36, 55, 53, 97, 54,
            49, 50, 54, 101, 45, 52, 50, 55, 102, 45, 52, 57, 97, 49,
            45, 97, 50, 99, 49, 45, 54, 50, 49, 49, 52, 51, 99, 98,
            57, 100, 98, 51, 0, 0, 0, 60, 123, 34, 100, 105, 97, 108,
            111, 103, 34, 58, 123, 34, 98, 111, 116, 95, 110, 97, 109,
            101, 34, 58, 34, 232, 177, 134, 229, 140, 133, 34, 44, 34,
            100, 105, 97, 108, 111, 103, 95, 105, 100, 34, 58, 34, 34,
            44, 34, 101, 120, 116, 114, 97, 34, 58, 110, 117, 108, 108,
            125, 125,
        ])
        self.assertEqual(frame, expected)

    def test_parse_server_json_event(self):
        payload = json.dumps({"dialog_id": "d1"}, separators=(",", ":")).encode()
        frame = bytes([17, 148, 16, 0])
        frame += (150).to_bytes(4, "big")
        frame += (36).to_bytes(4, "big")
        frame += b"75a6126e-427f-49a1-a2c1-621143cb9db3"
        frame += len(payload).to_bytes(4, "big")
        frame += payload

        parsed = realtime_dialog_smoke.parse_realtime_frame(frame)

        self.assertEqual(parsed.event, 150)
        self.assertEqual(parsed.session_id, "75a6126e-427f-49a1-a2c1-621143cb9db3")
        self.assertEqual(parsed.json_payload, {"dialog_id": "d1"})

    def test_build_chat_text_trigger_event(self):
        event, payload = realtime_dialog_smoke.build_trigger_event(
            "chat_text",
            content="请总结：今天有五条任务。",
            rag_title="消息",
        )

        self.assertEqual(event, 501)
        self.assertEqual(payload, {"content": "请总结：今天有五条任务。"})

    def test_build_chat_rag_trigger_event(self):
        event, payload = realtime_dialog_smoke.build_trigger_event(
            "chat_rag",
            content="今天有五条任务。",
            rag_title="日程todo",
        )

        self.assertEqual(event, 502)
        external_rag = json.loads(payload["external_rag"])
        self.assertEqual(external_rag, [{"title": "日程todo", "content": "今天有五条任务。"}])


if __name__ == "__main__":
    unittest.main()
