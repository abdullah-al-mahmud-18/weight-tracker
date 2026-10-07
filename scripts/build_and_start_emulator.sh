#!/usr/bin/env bash
# Builds a debug APK, then starts the project's Android emulator (if not
# already running) and blocks until it has finished booting, so a debug
# launch can proceed straight to `flutter run` against it. Suitable as a
# VS Code preLaunchTask.
set -euo pipefail

AVD_NAME="medium_phone"
DEVICE_ID="emulator-5554"
LOG_FILE="/tmp/weight_tracker_emulator.log"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Flutter: $FLUTTER override, else fvm if the project is pinned, else the
# FVM stable SDK, else whatever is on PATH.
if [ -n "${FLUTTER:-}" ]; then
  flutter_cmd=("$FLUTTER")
elif [ -f .fvmrc ] && command -v fvm >/dev/null; then
  flutter_cmd=(fvm flutter)
elif [ -x "$HOME/fvm/versions/stable/bin/flutter" ]; then
  flutter_cmd=("$HOME/fvm/versions/stable/bin/flutter")
else
  flutter_cmd=(flutter)
fi

# Use the SDK's adb; a second system adb can fight over the adb server.
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
ADB="$SDK_DIR/platform-tools/adb"
[ -x "$ADB" ] || ADB="adb"

echo "Building debug APK..."
"${flutter_cmd[@]}" pub get
"${flutter_cmd[@]}" build apk --debug

if ! "$ADB" devices | grep -qE "^${DEVICE_ID}\s+device$"; then
  echo "Starting emulator '${AVD_NAME}' (log: ${LOG_FILE})..."
  nohup android emulator start "${AVD_NAME}" >"${LOG_FILE}" 2>&1 &
  "$ADB" -s "${DEVICE_ID}" wait-for-device
fi

echo "Waiting for emulator to finish booting..."
until [ "$("$ADB" -s "${DEVICE_ID}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
  sleep 2
done

echo "Emulator ready."
