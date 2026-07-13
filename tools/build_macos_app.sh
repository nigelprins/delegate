#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/.build/Delegate.app"

swift build --package-path "$ROOT" -c release --product delegate
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/delegate" "$APP/Contents/MacOS/Delegate"
cp "$ROOT/apps/macos/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "$APP"
