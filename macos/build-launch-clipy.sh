#!/usr/bin/env bash
# Build ~/Applications/Launch Clipy.app from the Automator workflow source
# and register it as a login item. Safe to re-run.
#
# Clipy has no built-in "launch at login" option, so the workflow is wrapped in
# a tiny Automator applet that runs `open -a Clipy` and quits.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/launch-clipy"
APP="$HOME/Applications/Launch Clipy.app"
STUB="/System/Library/CoreServices/Automator Application Stub.app/Contents/MacOS/Automator Application Stub"

# shellcheck source=macos/login-items.sh
source "$HERE/login-items.sh"

if [[ ! -e "/Applications/Clipy.app" ]]; then
  echo "    - Clipy not installed — skipping Launch Clipy build"
  exit 0
fi

if [[ ! -x "$STUB" ]]; then
  echo "    ! Automator Application Stub not found at:" >&2
  echo "      $STUB" >&2
  echo "      Skipping Launch Clipy build." >&2
  exit 0
fi

mkdir -p "$APP/Contents/MacOS"
cp "$SRC/Info.plist"     "$APP/Contents/Info.plist"
cp "$SRC/document.wflow" "$APP/Contents/document.wflow"
cp "$STUB"               "$APP/Contents/MacOS/Automator Application Stub"

add_login_item "$APP" true || true
