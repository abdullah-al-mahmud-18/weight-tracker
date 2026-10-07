#!/usr/bin/env bash
# Builds size-optimized Android release APKs, one per ABI (split, R8-shrunk,
# obfuscated). Debug symbols for de-obfuscating stack traces are written to
# build/symbols — keep them for each release you distribute.
#
# The arm64-v8a APK is then moved to the user's Downloads folder as
# weight_tracker_<version>.apk, with the version read from version.txt.
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

# Version from version.txt, e.g. "v1.0.1" (surrounding whitespace ignored).
version="$(tr -d '[:space:]' < version.txt)"
if [ -z "$version" ]; then
  echo "error: version.txt is empty" >&2
  exit 1
fi

# Ubuntu's Downloads folder (localized name via xdg-user-dir if available).
downloads_dir="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
if [ -z "$downloads_dir" ] || [ "$downloads_dir" = "$HOME" ]; then
  downloads_dir="$HOME/Downloads"
fi
mkdir -p "$downloads_dir"

apk_src=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apk_dest="$downloads_dir/weight_tracker_${version}.apk"
mv -f "$apk_src" "$apk_dest"

echo
echo "Built APKs:"
ls -lh build/app/outputs/flutter-apk/app-*-release.apk
echo
echo "Moved the arm64-v8a APK (for virtually all phones) to:"
echo "  $apk_dest"
echo "Install it with:"
echo "  adb install \"$apk_dest\""
