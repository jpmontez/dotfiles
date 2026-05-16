#!/usr/bin/env bash
# Build ~/Applications/Launch Clipy.app from the Automator workflow source
# and register it as a login item. Safe to re-run.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/launch-clipy" && pwd)"
APP="$HOME/Applications/Launch Clipy.app"
STUB="/System/Library/CoreServices/Automator Application Stub.app/Contents/MacOS/Automator Application Stub"

mkdir -p "$APP/Contents/MacOS"
cp "$SRC/Info.plist"     "$APP/Contents/Info.plist"
cp "$SRC/document.wflow" "$APP/Contents/document.wflow"
cp "$STUB"               "$APP/Contents/MacOS/Automator Application Stub"

osascript >/dev/null 2>&1 <<EOF || true
tell application "System Events"
  delete (every login item whose path is "$APP")
  make login item at end with properties {path:"$APP", hidden:true}
end tell
EOF
