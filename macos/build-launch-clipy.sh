#!/usr/bin/env bash
# Build ~/Applications/Launch Clipy.app from the Automator workflow source.
#
#   bash macos/build-launch-clipy.sh            build it (safe to re-run)
#   bash macos/build-launch-clipy.sh --check    report whether it is built:
#                                                 0 built, 1 missing, 3 n/a
#
# Registering the result as a login item is defaults.sh's job — it is a row in
# LOGIN_ITEM_APPS. The applet's own existence can't ride on that row, because an
# unbuilt applet is indistinguishable from an uninstalled app there, so --check
# lives here instead.
#
# Clipy has no built-in "launch at login" option, so the workflow is wrapped in
# a tiny Automator applet that runs `open -a Clipy` and quits.

set -euo pipefail

MODE=build
case "${1:-}" in
  --check) MODE=check ;;
  "")      ;;
  *)       echo "usage: ${0##*/} [--check]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/launch-clipy"
APP="$HOME/Applications/Launch Clipy.app"
STUB="/System/Library/CoreServices/Automator Application Stub.app/Contents/MacOS/Automator Application Stub"

# Nothing to build, and nothing to report as drift, when the app it launches
# isn't installed or Apple has moved the stub the applet is built from. Check
# mode exits 3 for those so callers don't mistake "can't build" for "built".
NA=0
[[ "$MODE" == check ]] && NA=3

if [[ ! -e "/Applications/Clipy.app" ]]; then
  [[ "$MODE" == build ]] && echo "    - Clipy not installed — skipping Launch Clipy build"
  exit "$NA"
fi

if [[ ! -x "$STUB" ]]; then
  if [[ "$MODE" == build ]]; then
    echo "    ! Automator Application Stub not found at:" >&2
    echo "      $STUB" >&2
    echo "      Skipping Launch Clipy build." >&2
  fi
  exit "$NA"
fi

if [[ "$MODE" == check ]]; then
  [[ -e "$APP" ]] && exit 0
  exit 1
fi

mkdir -p "$APP/Contents/MacOS"
cp "$SRC/Info.plist"     "$APP/Contents/Info.plist"
cp "$SRC/document.wflow" "$APP/Contents/document.wflow"
cp "$STUB"               "$APP/Contents/MacOS/Automator Application Stub"

echo "    ✓ Launch Clipy built at $APP"
