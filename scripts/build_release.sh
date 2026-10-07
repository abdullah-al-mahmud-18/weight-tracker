#!/usr/bin/env bash
# Builds size-optimized Android release APKs, one per ABI (split, R8-shrunk,
# obfuscated). Debug symbols for de-obfuscating stack traces are written to
# build/symbols — keep them for each release you distribute.
set -euo pipefail

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

"${flutter_cmd[@]}" pub get

"${flutter_cmd[@]}" build apk \
  --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/symbols

echo
echo "Built APKs:"
ls -lh build/app/outputs/flutter-apk/app-*-release.apk
echo
echo "For a phone, install app-arm64-v8a-release.apk (covers virtually all"
echo "Android devices from the last several years):"
echo "  adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
