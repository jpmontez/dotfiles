#!/usr/bin/env bash
# Login item helpers. Source this file; it defines functions and runs nothing.
#
#   add_login_item <app-path> [hidden]   register (idempotent, delete-then-add)
#   has_login_item <app-path>            true if already registered
#
# Registration goes through System Events, which requires the calling terminal
# to hold Automation permission for it. The first attempt raises a TCC prompt
# that cannot be scripted — if it is denied, every later call fails silently at
# the osascript level, so we surface a warning rather than swallowing it.

# Guard against double-sourcing.
[[ -n "${_LOGIN_ITEMS_SH:-}" ]] && return 0
_LOGIN_ITEMS_SH=1

# has_login_item <app-path>
# Counts matches rather than asking `exists login item whose path is …`, which
# errors with -1728 because the singular form can't coerce a filtered list.
has_login_item() {
  local app="$1" count
  count="$(osascript 2>/dev/null <<EOF
tell application "System Events" to return (count of (login items whose path is "$app"))
EOF
  )"
  [[ "${count:-0}" -gt 0 ]]
}

# add_login_item <app-path> [hidden]
# Returns 0 on success, 1 if the app is missing or registration failed.
add_login_item() {
  local app="$1" hidden="${2:-true}" name
  name="$(basename "$app" .app)"

  if [[ ! -e "$app" ]]; then
    echo "    - $name not installed — skipping login item"
    return 1
  fi

  if ! osascript >/dev/null 2>&1 <<EOF
tell application "System Events"
  delete (every login item whose path is "$app")
  make login item at end with properties {path:"$app", hidden:$hidden}
end tell
EOF
  then
    echo "    ! Could not register $name as a login item." >&2
    echo "      Grant this terminal Automation access to System Events in" >&2
    echo "      System Settings → Privacy & Security → Automation, then re-run." >&2
    return 1
  fi

  echo "    ✓ $name registered as a login item"
}
