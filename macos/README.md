# macOS

One-time system setup for fresh macOS installs. Not a stow package.

## Files

| File                          | Purpose                                                      |
|-------------------------------|--------------------------------------------------------------|
| `defaults.sh`                 | Apply system defaults (Dock, keyboard, trackpad, etc.)       |
| `build-launch-clipy.sh`       | Build the Launch Clipy Automator app & register login item   |
| `launch-clipy/document.wflow` | Automator workflow source — runs `open -a Clipy`             |
| `launch-clipy/Info.plist`     | App bundle metadata for the Launch Clipy app                 |

## Running

`bootstrap.sh` prompts to run `defaults.sh` automatically on macOS. To run on demand:

```bash
bash macos/defaults.sh
```

Both scripts are idempotent — safe to re-run.

## What gets configured

- **Appearance** — auto-switching light/dark, hidden menu bar, no minimize on double-click
- **Keyboard** — Caps Lock → Left Control (HID modifier mapping, all keyboards)
- **Trackpad** — tap to click
- **Dock** — autohide, left orientation, no recent apps; populated via `dockutil` with Safari, Messages, Mail, Calendar, Music, iPhone Mirroring, System Settings, Ghostty, plus a Downloads stack
- **Menu bar** — Control Center icon and Now Playing visible; clock shows AM/PM and day of week
- **SizeUp** — menu bar icon hidden, no popup on disabled state
- **Clipy** — status item hidden (hotkey-only access)
- **Launch Clipy** — built at `~/Applications/Launch Clipy.app` and registered as a Login Item

## Manual follow-up

The script can't do everything itself:

- **Log out and back in** for the Caps Lock remap to apply (HID mappings only load at login).
- **Register Login Items** for SizeUp, Mullvad VPN, and Amphetamine via System Settings → General → Login Items. The apps themselves are installed by `brew bundle` (see [`Brewfile`](../Brewfile)); Launch Clipy is registered automatically.

## How the Caps Lock remap works

macOS stores keyboard modifier remappings in a per-host (ByHost) plist under the global domain. The script writes a single entry:

```
com.apple.keyboard.modifiermapping.0-0-0 = [
  { HIDKeyboardModifierMappingSrc: 0x700000039,  // page 0x07, usage 0x39 = Caps Lock
    HIDKeyboardModifierMappingDst: 0x7000000E4 } // page 0x07, usage 0xE4 = Left Control
]
```

The `0-0-0` suffix is `vendorID-productID-variant`. Using zeros applies the mapping to *all* keyboards rather than a specific connected device — so it survives swapping or pairing new keyboards.

## How Launch Clipy works

Clipy has no built-in "launch at login" option, so the workflow is wrapped in a tiny Automator applet:

1. `build-launch-clipy.sh` constructs the `.app` bundle by copying the system's `Automator Application Stub` binary from `/System/Library/CoreServices/` and pairing it with `launch-clipy/document.wflow` + `Info.plist`.
2. The workflow runs `open -a Clipy` via the Run Shell Script action.
3. The script registers the resulting app as a Login Item via `osascript`.

Editing the launcher behavior is a matter of changing `launch-clipy/document.wflow` (e.g. the `COMMAND_STRING` value) and re-running the build script.
