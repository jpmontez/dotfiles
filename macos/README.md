# macOS

One-time system setup for fresh macOS installs. Not a stow package.
`defaults.sh` is the only script here.

```bash
bash macos/defaults.sh            # apply
bash macos/defaults.sh --check    # report drift, write nothing, exit 1 if any
```

Idempotent — safe to re-run. `bootstrap.sh` prompts to run it; `doctor.sh` calls
`--check`.

## How `--check` stays honest

Every scalar setting lives in one `SETTINGS` table at the top of `defaults.sh`:

```
scope|domain|key|type|value
```

Both modes walk that same table — apply calls `defaults write`, check calls
`defaults read` and compares — so a check can never drift out of sync with what
apply writes. Booleans are normalised before comparison, since `defaults read`
prints `0`/`1` rather than `false`/`true`.

The Caps Lock remap, Dock contents, login items, Touch ID, and the firewall need
more than a scalar comparison, so each has a matching `process_*` function with
an explicit check branch.

## What gets configured

Read `SETTINGS` for the exact list. In summary: appearance, keyboard, text
substitution, trackpad, Dock, Finder, screenshots, screen saver, menu bar, and
per-app defaults for SizeUp and Clipy. Beyond the table:

- **Dock contents** — populated via `dockutil` from `DOCK_APPS`. Entries whose app doesn't exist on this macOS version are skipped rather than aborting the run.
- **Screen saver** — password required immediately. *Best-effort:* since Ventura this pane is partly system-managed and the write may not stick; `--check` shows it as drift if so.
- **Security** — Touch ID for `sudo` and the application firewall with stealth mode. FileVault is never touched here — turning it on generates a recovery key a human has to record, so `doctor.sh` reports its status instead.
- **Login items** — `LOGIN_ITEM_APPS`, registered hidden via System Events. Apps that aren't installed are skipped.

Settings that need `sudo` (Touch ID, firewall) prompt once up front rather than
midway through. `--check` never needs sudo.

## Manual follow-up

- **Log out and back in** for the Caps Lock remap to apply (HID mappings only load at login).
- **Grant Automation access.** The first login-item registration raises a TCC prompt for System Events that can't be scripted. If it's denied, `defaults.sh` prints a warning naming the app and the setting to fix — it doesn't fail silently.

## How the Caps Lock remap works

macOS stores keyboard modifier remappings in a per-host (ByHost) plist under the
global domain. The script writes a single entry:

```
com.apple.keyboard.modifiermapping.0-0-0 = [
  { HIDKeyboardModifierMappingSrc: 0x700000039,  // page 0x07, usage 0x39 = Caps Lock
    HIDKeyboardModifierMappingDst: 0x7000000E4 } // page 0x07, usage 0xE4 = Left Control
]
```

The `0-0-0` suffix is `vendorID-productID-variant`. Using zeros applies the
mapping to *all* keyboards rather than a specific connected device — so it
survives swapping or pairing new keyboards.

## How Touch ID for sudo works

The script writes `/etc/pam.d/sudo_local` from Apple's own
`/etc/pam.d/sudo_local.template`, uncommenting the `pam_tid.so` line. Editing
`/etc/pam.d/sudo` directly would work too, but macOS overwrites that file on
system updates; `sudo_local` is the supported override and survives them.
