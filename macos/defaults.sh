#!/usr/bin/env bash
# Apply macOS system defaults. Idempotent; safe to re-run.
# Some changes (Caps Lock remap) require logout to take effect.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Quit System Settings so it doesn't clobber writes on save.
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

echo ">>> Applying macOS defaults..."

# ---- Appearance ----
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true
defaults write NSGlobalDomain _HIHideMenuBar                           -bool true
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick            -bool false

# ---- Keyboard: Caps Lock → Left Control ----
# Full HID value = (page << 32) | usage; page 0x07 = Keyboard/Keypad.
# Suffix 0-0-0 applies the mapping to all keyboards (vendor 0, product 0).
HID_CAPS_LOCK=$((0x700000039))  # usage 0x39 = Caps Lock
HID_LEFT_CTRL=$((0x7000000E4))  # usage 0xE4 = Left Control
defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
  "<dict>
    <key>HIDKeyboardModifierMappingSrc</key><integer>$HID_CAPS_LOCK</integer>
    <key>HIDKeyboardModifierMappingDst</key><integer>$HID_LEFT_CTRL</integer>
  </dict>"

# ---- Trackpad ----
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1

# ---- Dock ----
defaults write com.apple.dock autohide     -bool true
defaults write com.apple.dock orientation  -string "left"
defaults write com.apple.dock mru-spaces   -bool false
defaults write com.apple.dock show-recents -bool false

# ---- Dock apps ----
dock_apps=(
  "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Mail.app"
  "/System/Applications/Calendar.app"
  "/System/Applications/Music.app"
  "/System/Applications/iPhone Mirroring.app"
  "/System/Applications/System Settings.app"
  "/Applications/Ghostty.app"
)

if command -v dockutil &>/dev/null; then
  dockutil --remove all --no-restart >/dev/null
  for app in "${dock_apps[@]}"; do
    dockutil --add "$app" --no-restart >/dev/null
  done
  dockutil --add "$HOME/Downloads" --view fan --display folder --no-restart >/dev/null
else
  echo ">>> dockutil missing — skipping Dock app setup. Run 'brew bundle' from the repo root, then re-run."
fi

# ---- Menu bar ----
defaults write com.apple.menuextra.clock ShowAMPM      -bool true
defaults write com.apple.menuextra.clock ShowDate      -bool false
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.controlcenter "NSStatusItem VisibleCC BentoBox-0" -bool true
defaults write com.apple.controlcenter "NSStatusItem VisibleCC NowPlaying" -bool true

# ---- Third-party apps ----
defaults write com.irradiatedsoftware.SizeUp MenuEnabled                  -bool false
defaults write com.irradiatedsoftware.SizeUp suppressMenuBarDisabledPopup -bool true
defaults write com.clipy-app.Clipy           kCPYPrefShowStatusItemKey    -bool false

# ---- Build Launch Clipy login item ----
bash "$DOTFILES_DIR/macos/build-launch-clipy.sh"

# ---- Restart affected services ----
for svc in Dock Finder SystemUIServer ControlCenter; do
  killall "$svc" &>/dev/null || true
done

cat <<'EOF'

>>> macOS defaults applied.

Manual follow-up:
  - Log out and back in for the Caps Lock → Control remap to take effect.
  - Add SizeUp, Mullvad VPN, and Amphetamine as Login Items via
    System Settings → General → Login Items. (The apps themselves are
    installed by `brew bundle`; Launch Clipy is registered automatically.)
EOF
