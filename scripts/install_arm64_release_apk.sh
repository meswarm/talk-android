#!/usr/bin/env bash
# Build release APK (arm64 split) and install to the connected Android device via adb.
# Run from anywhere; paths are relative to the Flutter app root (parent of scripts/).
#
# Usage:
#   ./scripts/install_arm64_release_apk.sh
#   ./scripts/install_arm64_release_apk.sh --build-only
#
# Optional: ANDROID_SERIAL=<device_id> when multiple devices are connected.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APK_REL="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
APK_ABS="$ROOT/$APK_REL"

BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=1 ;;
    -h|--help)
      echo "Usage: $0 [--build-only]"
      echo "  Builds: flutter build apk --release --split-per-abi"
      echo "  Installs: adb install -r $APK_REL"
      exit 0
      ;;
  esac
done

echo "==> Flutter project: $ROOT"
echo "==> flutter build apk --release --split-per-abi"
flutter build apk --release --split-per-abi

if [[ ! -f "$APK_ABS" ]]; then
  echo "error: expected APK not found: $APK_ABS" >&2
  exit 1
fi

echo "==> Built: $APK_ABS ($(du -h "$APK_ABS" | cut -f1))"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  echo "==> --build-only: skip adb install"
  exit 0
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "error: adb not in PATH" >&2
  exit 1
fi

echo "==> adb devices:"
adb devices

echo "==> adb install -r \"$APK_REL\""
if ! adb install -r "$APK_ABS"; then
  echo >&2
  echo "Install failed. On the phone, allow the install prompt (USB debugging / package installer)." >&2
  echo "If you see INSTALL_FAILED_ABORTED: User rejected permissions — unlock the screen and accept." >&2
  exit 1
fi

echo "==> Success."
