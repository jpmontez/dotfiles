#!/usr/bin/env bash
# Apply macOS system defaults. Idempotent; safe to re-run.
#
#   bash macos/defaults.sh            apply everything
#   bash macos/defaults.sh --check    report drift, write nothing, exit 1 if any
#
# Settings live in one SETTINGS table consumed by both modes, so a check can
# never fall out of sync with what apply writes.
#
# Some changes (Caps Lock remap) require logout to take effect.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "macos/defaults.sh: macOS only (detected $(uname))." >&2
  exit 1
fi

MODE=apply
case "${1:-}" in
  --check) MODE=check ;;
  "")      ;;
  *)       echo "usage: ${0##*/} [--check]" >&2; exit 2 ;;
esac

drift=0
note_drift() { drift=1; echo "  ✗ $*"; }
note_ok()    { [[ "$MODE" == check ]] && echo "  ✓ $*"; return 0; }

# ---------------------------------------------------------------------------
# Settings table
#
#   scope|domain|key|type|value
#
# scope   user        → defaults write
#         currenthost → defaults -currentHost write (per-machine, ByHost plist)
# domain  -g is the global domain in -currentHost scope; NSGlobalDomain elsewhere
# type    bool | int | string
# ---------------------------------------------------------------------------
SETTINGS=(
  # ---- Appearance ----
  "user|NSGlobalDomain|AppleInterfaceStyleSwitchesAutomatically|bool|true"
  "user|NSGlobalDomain|_HIHideMenuBar|bool|true"
  "user|NSGlobalDomain|AppleMiniaturizeOnDoubleClick|bool|false"

  # ---- Keyboard ----
  # The press-and-hold accent popup suppresses key repeat, which breaks
  # held-down motions in nvim. Disable it and speed the repeat up.
  "user|NSGlobalDomain|ApplePressAndHoldEnabled|bool|false"
  "user|NSGlobalDomain|KeyRepeat|int|2"
  "user|NSGlobalDomain|InitialKeyRepeat|int|15"
  "user|NSGlobalDomain|AppleKeyboardUIMode|int|3"  # Tab moves between all controls

  # ---- Text substitution ----
  # Smart quotes and em-dashes corrupt code, paths, and commit messages.
  "user|NSGlobalDomain|NSAutomaticQuoteSubstitutionEnabled|bool|false"
  "user|NSGlobalDomain|NSAutomaticDashSubstitutionEnabled|bool|false"
  "user|NSGlobalDomain|NSAutomaticCapitalizationEnabled|bool|false"
  "user|NSGlobalDomain|NSAutomaticPeriodSubstitutionEnabled|bool|false"
  "user|NSGlobalDomain|NSAutomaticSpellingCorrectionEnabled|bool|false"

  # ---- Trackpad ----
  "user|com.apple.AppleMultitouchTrackpad|Clicking|bool|true"
  "user|com.apple.driver.AppleBluetoothMultitouch.trackpad|Clicking|bool|true"
  "currenthost|-g|com.apple.mouse.tapBehavior|int|1"

  # ---- Dock ----
  "user|com.apple.dock|autohide|bool|true"
  "user|com.apple.dock|orientation|string|left"
  "user|com.apple.dock|mru-spaces|bool|false"
  "user|com.apple.dock|show-recents|bool|false"

  # ---- Finder ----
  "user|NSGlobalDomain|AppleShowAllExtensions|bool|true"
  "user|com.apple.finder|ShowPathbar|bool|true"
  "user|com.apple.finder|ShowStatusBar|bool|true"
  "user|com.apple.finder|_FXShowPosixPathInTitle|bool|true"
  "user|com.apple.finder|FXPreferredViewStyle|string|Nlsv"  # list view
  "user|com.apple.finder|FXEnableExtensionChangeWarning|bool|false"
  "user|com.apple.finder|FXDefaultSearchScope|string|SCcf"  # search current folder
  # System-level counterpart to the `dsclean` alias in zsh/.aliases.
  "user|com.apple.desktopservices|DSDontWriteNetworkStores|bool|true"
  "user|com.apple.desktopservices|DSDontWriteUSBStores|bool|true"

  # ---- Screenshots ----
  "user|com.apple.screencapture|location|string|$HOME/Desktop/Screenshots"
  "user|com.apple.screencapture|type|string|png"
  "user|com.apple.screencapture|disable-shadow|bool|true"
  "user|com.apple.screencapture|show-thumbnail|bool|false"

  # ---- Screen saver ----
  # Best-effort: since Ventura this pane is partly system-managed and the write
  # may not stick. --check surfaces that rather than letting it fail silently.
  "currenthost|com.apple.screensaver|askForPassword|int|1"
  "currenthost|com.apple.screensaver|askForPasswordDelay|int|0"

  # ---- Menu bar ----
  "user|com.apple.menuextra.clock|ShowAMPM|bool|true"
  "user|com.apple.menuextra.clock|ShowDate|bool|false"
  "user|com.apple.menuextra.clock|ShowDayOfWeek|bool|true"
  "user|com.apple.controlcenter|NSStatusItem VisibleCC BentoBox-0|bool|true"
  "user|com.apple.controlcenter|NSStatusItem VisibleCC NowPlaying|bool|true"

  # ---- Third-party apps ----
  "user|com.irradiatedsoftware.SizeUp|MenuEnabled|bool|false"
  "user|com.irradiatedsoftware.SizeUp|suppressMenuBarDisabledPopup|bool|true"
  "user|com.clipy-app.Clipy|kCPYPrefShowStatusItemKey|bool|false"
)

# Dock contents, rebuilt in order. Paths that don't exist on this macOS
# version are skipped rather than aborting the run.
DOCK_APPS=(
  "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Mail.app"
  "/System/Applications/Calendar.app"
  "/System/Applications/Music.app"
  "/System/Applications/iPhone Mirroring.app"  # Sequoia and later
  "/System/Applications/System Settings.app"
  "/Applications/Ghostty.app"
)

# Apps to register as login items.
LOGIN_ITEM_APPS=(
  "/Applications/SizeUp.app"
  "/Applications/Mullvad VPN.app"
  "/Applications/Amphetamine.app"
  "/Applications/Ice.app"
  "/Applications/Clipy.app"
)

# Caps Lock → Left Control, as an HID modifier mapping.
# Full HID value = (page << 32) | usage; page 0x07 = Keyboard/Keypad.
HID_CAPS_LOCK=$((0x700000039))  # usage 0x39 = Caps Lock
HID_LEFT_CTRL=$((0x7000000E4))  # usage 0xE4 = Left Control

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# `defaults read` prints 0/1 for booleans; normalise so comparisons work.
normalize_bool() {
  case "$1" in
    true|1|YES) echo 1 ;;
    false|0|NO) echo 0 ;;
    *)          echo "$1" ;;
  esac
}

# read_default <scope> <domain> <key>
read_default() {
  local scope="$1" domain="$2" key="$3"
  if [[ "$scope" == currenthost ]]; then
    defaults -currentHost read "$domain" "$key" 2>/dev/null
  else
    defaults read "$domain" "$key" 2>/dev/null
  fi
}

# write_default <scope> <domain> <key> <type> <value>
write_default() {
  local scope="$1" domain="$2" key="$3" type="$4" value="$5"
  if [[ "$scope" == currenthost ]]; then
    defaults -currentHost write "$domain" "$key" "-$type" "$value"
  else
    defaults write "$domain" "$key" "-$type" "$value"
  fi
}

process_settings() {
  local entry scope domain key type value actual want
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -r scope domain key type value <<<"$entry"

    if [[ "$MODE" == apply ]]; then
      write_default "$scope" "$domain" "$key" "$type" "$value"
      continue
    fi

    actual="$(read_default "$scope" "$domain" "$key")" || true
    want="$value"
    if [[ "$type" == bool ]]; then
      actual="$(normalize_bool "$actual")"
      want="$(normalize_bool "$want")"
    fi

    if [[ -z "$actual" ]]; then
      note_drift "$domain $key — unset, want $value"
    elif [[ "$actual" != "$want" ]]; then
      note_drift "$domain $key — want $value, got $actual"
    else
      note_ok "$domain $key"
    fi
  done
}

process_caps_lock() {
  local current
  current="$(defaults -currentHost read -g com.apple.keyboard.modifiermapping.0-0-0 2>/dev/null || true)"

  if [[ "$MODE" == check ]]; then
    if [[ "$current" == *"$HID_CAPS_LOCK"* && "$current" == *"$HID_LEFT_CTRL"* ]]; then
      note_ok "Caps Lock → Left Control"
    else
      note_drift "Caps Lock → Left Control not mapped"
    fi
    return 0
  fi

  # The 0-0-0 suffix is vendorID-productID-variant; zeros apply the mapping to
  # every keyboard rather than one specific device, so it survives swapping or
  # pairing new hardware.
  defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
    "<dict>
      <key>HIDKeyboardModifierMappingSrc</key><integer>$HID_CAPS_LOCK</integer>
      <key>HIDKeyboardModifierMappingDst</key><integer>$HID_LEFT_CTRL</integer>
    </dict>"
}

process_dock_apps() {
  local app present=()
  for app in "${DOCK_APPS[@]}"; do
    [[ -e "$app" ]] && present+=("$app")
  done

  if ! command -v dockutil &>/dev/null; then
    note_drift "dockutil missing — Dock contents unmanaged (brew bundle installs it)"
    return 0
  fi

  if [[ "$MODE" == check ]]; then
    local listed name missing=0
    listed="$(dockutil --list 2>/dev/null || true)"
    for app in "${present[@]}"; do
      name="${app##*/}"
      [[ "$listed" == *"${name%.app}"* ]] || { missing=1; break; }
    done
    if (( missing )); then
      note_drift "Dock contents differ from DOCK_APPS"
    else
      note_ok "Dock contents"
    fi
    return 0
  fi

  dockutil --remove all --no-restart >/dev/null
  for app in "${present[@]}"; do
    dockutil --add "$app" --no-restart >/dev/null
  done
  dockutil --add "$HOME/Downloads" --view fan --display folder --no-restart >/dev/null
}

# Registration goes through System Events, which requires the calling terminal
# to hold Automation permission for it. The first attempt raises a TCC prompt
# that cannot be scripted — if it is denied, every later call fails silently at
# the osascript level, so we surface a warning rather than swallowing it.
process_login_items() {
  local app name count
  for app in "${LOGIN_ITEM_APPS[@]}"; do
    [[ -e "$app" ]] || continue
    name="${app##*/}"
    name="${name%.app}"

    if [[ "$MODE" == check ]]; then
      # Counts matches rather than asking `exists login item whose path is …`,
      # which errors with -1728 because the singular form can't coerce a
      # filtered list.
      count="$(osascript 2>/dev/null <<EOF
tell application "System Events" to return (count of (login items whose path is "$app"))
EOF
      )"
      if [[ "${count:-0}" -gt 0 ]]; then
        note_ok "login item: $name"
      else
        note_drift "login item missing: $name"
      fi
    elif osascript >/dev/null 2>&1 <<EOF
tell application "System Events"
  delete (every login item whose path is "$app")
  make login item at end with properties {path:"$app", hidden:true}
end tell
EOF
    then
      echo "    ✓ $name registered as a login item"
    else
      echo "    ! Could not register $name as a login item." >&2
      echo "      Grant this terminal Automation access to System Events in" >&2
      echo "      System Settings → Privacy & Security → Automation, then re-run." >&2
    fi
  done
}

# Touch ID for sudo. Writing /etc/pam.d/sudo_local rather than editing
# /etc/pam.d/sudo means the setting survives OS updates.
process_touch_id_sudo() {
  local target=/etc/pam.d/sudo_local template=/etc/pam.d/sudo_local.template

  if [[ -f "$target" ]] && grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$target"; then
    note_ok "Touch ID for sudo"
    return 0
  fi

  if [[ "$MODE" == check ]]; then
    note_drift "Touch ID for sudo not enabled"
    return 0
  fi

  if [[ ! -f "$template" ]]; then
    echo "  ! $template not found — skipping Touch ID for sudo" >&2
    return 0
  fi

  sudo sed 's/^#auth/auth/' "$template" | sudo tee "$target" >/dev/null
  sudo chmod 444 "$target"
  echo "  ✓ Touch ID for sudo enabled"
}

process_firewall() {
  local fw=/usr/libexec/ApplicationFirewall/socketfilterfw

  [[ -x "$fw" ]] || { echo "  ! socketfilterfw not found — skipping firewall" >&2; return 0; }

  if "$fw" --getglobalstate 2>/dev/null | grep -q "enabled"; then
    note_ok "Application firewall"
    return 0
  fi

  if [[ "$MODE" == check ]]; then
    note_drift "Application firewall is off"
    return 0
  fi

  # socketfilterfw is deprecated; revisit if a future macOS drops it.
  sudo "$fw" --setglobalstate on >/dev/null
  sudo "$fw" --setstealthmode on >/dev/null
  echo "  ✓ Application firewall enabled"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

if [[ "$MODE" == apply ]]; then
  echo ">>> Applying macOS defaults..."
  # Quit System Settings so it doesn't clobber writes on save.
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
  # Prime sudo up front so the password prompt lands here rather than midway.
  sudo -v
  mkdir -p "$HOME/Desktop/Screenshots"
else
  echo ">>> Checking macOS defaults..."
fi

process_settings
process_caps_lock
process_dock_apps
process_touch_id_sudo
process_firewall
process_login_items

if [[ "$MODE" == check ]]; then
  echo ""
  if (( drift )); then
    echo ">>> Drift detected. Apply with: bash macos/defaults.sh"
    exit 1
  fi
  echo ">>> macOS defaults match the repo."
  exit 0
fi

# ---- Restart affected services ----
for svc in cfprefsd Dock Finder SystemUIServer ControlCenter; do
  killall "$svc" &>/dev/null || true
done

cat <<'EOF'

>>> macOS defaults applied.

Manual follow-up:
  - Log out and back in for the Caps Lock → Control remap to take effect.
EOF
