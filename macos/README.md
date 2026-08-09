# macOS

One-time system setup for fresh macOS installs. Not a stow package.

## Files

| File                          | Purpose                                                      |
|-------------------------------|--------------------------------------------------------------|
| `defaults.sh`                 | Apply (or check) system defaults — Dock, keyboard, Finder, security |
| `login-items.sh`              | Sourced helpers: `add_login_item`, `has_login_item`          |
| `build-launch-clipy.sh`       | Build (or `--check`) the Launch Clipy Automator app          |
| `launch-clipy/document.wflow` | Automator workflow source — runs `open -a Clipy`             |
| `launch-clipy/Info.plist`     | App bundle metadata for the Launch Clipy app                 |

## Running

`bootstrap.sh` prompts to run `defaults.sh` automatically on macOS. To run on demand:

```bash
bash macos/defaults.sh            # apply
bash macos/defaults.sh --check    # report drift, write nothing, exit 1 if any
```

Both scripts are idempotent — safe to re-run. `--check` is what `doctor.sh` calls.

## How `--check` stays honest

Every scalar setting lives in one `SETTINGS` table at the top of `defaults.sh`:

```
scope|domain|key|type|value
```

Both modes walk that same table — apply calls `defaults write`, check calls
`defaults read` and compares — so a check can never drift out of sync with what
apply writes. Booleans are normalised before comparison, since `defaults read`
prints `0`/`1` rather than `false`/`true`.

The Caps Lock remap, Dock contents, login items, Touch ID, and the firewall
need more than a scalar comparison, so each has a matching `process_*` function
with an explicit check branch.

## What gets configured

- **Appearance** — auto-switching light/dark, hidden menu bar, no minimize on double-click
- **Keyboard** — Caps Lock → Left Control (HID modifier mapping, all keyboards); press-and-hold disabled so key repeat works in nvim; fast repeat rates; full keyboard access
- **Text** — smart quotes, dashes, capitalization, period substitution, and auto-correct all off (they corrupt code and commit messages)
- **Trackpad** — tap to click, built-in and Magic Trackpad
- **Dock** — autohide, left orientation, no recent apps; populated via `dockutil` with Safari, Messages, Mail, Calendar, Music, iPhone Mirroring, System Settings, Ghostty, plus a Downloads stack. Entries whose app doesn't exist on this macOS version are skipped rather than aborting the run.
- **Finder** — all extensions shown, path bar, status bar, POSIX path in title, list view by default, search scoped to the current folder, no extension-change warning, no `.DS_Store` on network or USB volumes
- **Screenshots** — PNG, no window shadow, no floating thumbnail, saved to `~/Desktop/Screenshots`
- **Screen saver** — password required immediately. *Best-effort:* since Ventura this pane is partly system-managed and the write may not stick; `--check` will show it as drift if so.
- **Menu bar** — Control Center icon and Now Playing visible; clock shows AM/PM and day of week
- **Security** — Touch ID for `sudo`, application firewall with stealth mode. FileVault is never touched here — turning it on generates a recovery key a human has to record, so `doctor.sh` reports its status instead.
- **SizeUp** — menu bar icon hidden, no popup on disabled state
- **Clipy** — status item hidden (hotkey-only access)
- **Login items** — SizeUp, Mullvad VPN, Amphetamine, Ice, and Launch Clipy registered automatically; apps that aren't installed are skipped

Settings that need `sudo` (Touch ID, firewall) prompt once up front rather than
midway through. `--check` never needs sudo.

## Manual follow-up

- **Log out and back in** for the Caps Lock remap to apply (HID mappings only load at login).
- **Grant Automation access.** The first login-item registration raises a TCC prompt for System Events that can't be scripted. If it's denied, `defaults.sh` prints a warning naming the app and the setting to fix — it no longer fails silently.

## How the Caps Lock remap works

macOS stores keyboard modifier remappings in a per-host (ByHost) plist under the global domain. The script writes a single entry:

```
com.apple.keyboard.modifiermapping.0-0-0 = [
  { HIDKeyboardModifierMappingSrc: 0x700000039,  // page 0x07, usage 0x39 = Caps Lock
    HIDKeyboardModifierMappingDst: 0x7000000E4 } // page 0x07, usage 0xE4 = Left Control
]
```

The `0-0-0` suffix is `vendorID-productID-variant`. Using zeros applies the mapping to *all* keyboards rather than a specific connected device — so it survives swapping or pairing new keyboards.

## How Touch ID for sudo works

The script writes `/etc/pam.d/sudo_local` from Apple's own
`/etc/pam.d/sudo_local.template`, uncommenting the `pam_tid.so` line. Editing
`/etc/pam.d/sudo` directly would work too, but macOS overwrites that file on
system updates; `sudo_local` is the supported override and survives them.

## How Launch Clipy works

Clipy has no built-in "launch at login" option, so the workflow is wrapped in a tiny Automator applet:

1. `build-launch-clipy.sh` constructs the `.app` bundle by copying the system's `Automator Application Stub` binary from `/System/Library/CoreServices/` and pairing it with `launch-clipy/document.wflow` + `Info.plist`.
2. The workflow runs `open -a Clipy` via the Run Shell Script action.
3. The built app is a row in `defaults.sh`'s `LOGIN_ITEM_APPS`, so the normal login-item pass registers it as hidden.

`--check` covers both halves: `build-launch-clipy.sh --check` reports whether the
applet exists (it stays quiet when Clipy itself isn't installed, since there is
nothing to build), and the `LOGIN_ITEM_APPS` row reports whether it's registered.

The build is skipped with a message if Clipy isn't installed or if Apple has
moved the Automator stub. Editing the launcher behavior is a matter of changing
`launch-clipy/document.wflow` (e.g. the `COMMAND_STRING` value) and re-running
the build script.
