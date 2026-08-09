# dotfiles

Personal dotfiles managed with [GNU stow](https://www.gnu.org/software/stow/). Works on macOS and WSL 2 (Ubuntu).

---

## Quick Start

```bash
git clone --recurse-submodules https://github.com/jpmontez/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles
./bootstrap.sh
exec zsh
```

`bootstrap.sh` detects your platform, installs dependencies (via `brew bundle` on macOS — see [`Brewfile`](Brewfile) — or `apt-get` on Linux/WSL), initializes submodules, symlinks every package, and sets zsh as the default shell. On macOS it also asks whether this is a personal machine, and prompts to apply system defaults — see [macOS Configuration](#macos-configuration).

### Options

| Flag | Effect |
|------|--------|
| `--yes`, `-y` | Assume defaults, never prompt. Implies core-only packages. |
| `--personal` | Install [`Brewfile.personal`](Brewfile.personal) too, and remember it |
| `--no-personal` | Core packages only, and remember it |
| `--no-defaults` | Skip `macos/defaults.sh` |
| `--check` | Report drift via `doctor.sh` and exit, changing nothing |

---

## What's Inside

### Stow packages

Each directory mirrors `$HOME` and is symlinked in by `stow`:

| Package   | Symlinks to `$HOME`               | Notes                          |
|-----------|-----------------------------------|--------------------------------|
| `zsh`     | `.zshrc`, `.zprofile`, `.aliases` | Shell config + prezto init     |
| `git`     | `.gitconfig`                      | Git identity and aliases       |
| `tmux`    | `.tmux.conf`                      | Prefix, vim keys, copy-paste   |
| `ssh`     | `.ssh/config`                     | SSH agent, ForwardAgent. Stowed `--no-folding` — see [below](#why-ssh-is-stowed-differently) |
| `nvim`    | `.config/nvim`                    | Submodule: kickstart.nvim      |
| `base16`  | `.config/base16-shell`            | Submodule: base16 color scheme |
| `claude`  | `.claude/settings.json`           | Claude Code plugins, theme, model, notification hook |
| `zprezto` | `.zprezto`, `.zpreztorc`, etc.    | Manual symlinks via bootstrap  |

### Other files

| Path                | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `macos/`            | macOS system defaults & login-item setup                       |
| `Brewfile`          | Core CLI tools, Cask apps, and App Store apps — every machine   |
| `Brewfile.personal` | Opt-in media, games, and creative apps                          |
| `doctor.sh`         | Read-only drift check — see [Verifying](#verifying)             |
| `lib.sh`            | Shared package list and machine-tier helpers for both scripts   |

---

## Package Tiers

Two Brewfiles, so a work machine doesn't pull down Logic Pro:

- **[`Brewfile`](Brewfile)** — everything needed for a working machine: shell, editor, terminal, dev tooling, and the GUI apps used day to day.
- **[`Brewfile.personal`](Brewfile.personal)** — media, games, and creative apps.

`bootstrap.sh` asks once whether this is a personal machine and records the
answer in `.machine` (gitignored) as `PERSONAL=yes|no`. Later runs reuse it
without asking. To change your mind, re-run with `--personal` / `--no-personal`,
or edit `.machine` directly. `doctor.sh` reads the same file, so a core-only
machine is never nagged about personal apps.

Installing a tier on demand, without bootstrap:

```bash
brew bundle --file=Brewfile.personal
```

`mas` entries need the App Store signed in first — `brew bundle` can't do that
for you, and those entries will fail until you do. Bootstrap treats that as a
warning rather than a fatal error, so the rest of the setup still completes.

DaVinci Resolve, Blackmagic RAW, and Blackmagic Proxy Generator have no
Homebrew cask and must be installed by hand; they're listed in a comment block
at the end of `Brewfile.personal`.

---

## macOS Configuration

`bootstrap.sh` prompts (`y/N`) to run `macos/defaults.sh` on macOS. You can also run it independently:

```bash
bash macos/defaults.sh
```

Pass `--check` to report drift without writing anything:

```bash
bash macos/defaults.sh --check
```

It configures, end to end:

- **Appearance** — auto-switching light/dark, hidden menu bar
- **Keyboard** — Caps Lock → Left Control (HID-level, all keyboards), press-and-hold off so key repeat works in nvim, fast repeat rates
- **Text** — smart quotes, dashes, capitalization, and auto-correct off
- **Trackpad** — tap to click, built-in and Magic Trackpad
- **Dock** — left orientation, autohide, no recent apps, no MRU spaces; populated with a curated app list via `dockutil`
- **Finder** — extensions shown, path and status bars, POSIX path in title, list view, no `.DS_Store` on network or USB volumes
- **Screenshots** — PNG, no shadow, saved to `~/Desktop/Screenshots`
- **Menu bar** — Control Center icon and Now Playing visible
- **Clock** — AM/PM with day of week, no date
- **Security** — Touch ID for `sudo`, application firewall with stealth mode; FileVault is never changed automatically (`doctor.sh` reports its status)
- **Third-party apps** — sensible defaults for SizeUp and Clipy
- **Login items** — SizeUp, Mullvad VPN, Amphetamine, Ice, and a Launch Clipy Automator applet, all registered automatically

After running, **log out and back in** for the Caps Lock remap to take effect.

See [`macos/README.md`](macos/README.md) for details on each script, how the
`--check` table works, and how the remap / Automator workflow is constructed.

---

## Verifying

`doctor.sh` reports drift between this repo and the live machine. It is
read-only and exits 1 if anything has moved:

```bash
./doctor.sh
```

It checks:

| Check | Catches |
|-------|---------|
| Packages | Brewfile entries not installed, and installed packages listed in no in-scope Brewfile |
| Stow links | Broken or unstowed packages, and `~/.ssh` folded back into a symlink |
| macOS defaults | Any setting in `macos/defaults.sh` that no longer matches |
| Repo | Submodules off their recorded commits, dirty working tree |
| Environment | Wrong default shell, missing Xcode CLT, FileVault off |

`./bootstrap.sh --check` is a shortcut for the same thing.

---

## How It Works

Each stow package is a folder whose contents mirror `$HOME`. Running `stow --target="$HOME" <package>` creates symlinks in `$HOME` pointing back into this repo. For example, `zsh/.zshrc` becomes `~/.zshrc → ~/Development/dotfiles/zsh/.zshrc`.

This means:

- Editing a dotfile is just editing the file in this repo
- `git diff` always shows the live state of your config
- `stow --delete <package>` removes a package's symlinks

The repo must stay at `~/Development/dotfiles`. Stow's symlinks resolve relative to wherever the repo lives at the time `stow` runs — moving the directory later would break every link.

### Why `ssh` is stowed differently

When a package's directory has no counterpart in `$HOME`, stow "folds" it —
linking the whole directory rather than each file inside it. For `ssh` that
would make `~/.ssh` itself a symlink into this repo, so every key, `known_hosts`
entry, and control socket written there would land in the git working tree.

Bootstrap therefore stows `ssh` with `--no-folding`, leaving `~/.ssh` a real
directory (mode 700) that contains a symlinked `config` and nothing else from
the repo. `doctor.sh` flags it if it ever folds back.

---

## Submodules

Three dependencies are tracked as git submodules:

| Submodule                      | Repo                                   |
|-------------------------------|----------------------------------------|
| `zprezto`                     | `github.com/jpmontez/prezto`           |
| `nvim/.config/nvim`           | `github.com/jpmontez/kickstart.nvim`   |
| `base16/.config/base16-shell` | `github.com/chriskempson/base16-shell` |

`bootstrap.sh` initializes them automatically. To refresh manually:

```bash
git submodule update --init --recursive
```

---

## Platform Support

| Feature            | macOS                                | WSL 2 / Linux       |
|--------------------|--------------------------------------|---------------------|
| Package manager    | Homebrew (`Brewfile`)                | apt                 |
| Package tiers      | Core + optional personal             | n/a                 |
| Clipboard in tmux  | `reattach-to-user-namespace pbcopy`  | `xclip`             |
| Homebrew init      | `.zprofile` (guarded by `uname`)     | Skipped             |
| GOROOT             | `brew --prefix golang`               | Omitted from PATH   |
| System defaults    | Prompted during bootstrap            | n/a                 |
| `doctor.sh`        | All checks                           | Skips macOS defaults |

Platform detection happens at the top of `bootstrap.sh` using `uname` and `/proc/version`. Shell configs use inline `[[ "$(uname)" == "Darwin" ]]` guards so a single set of dotfiles works on both platforms.

---

## Post-Install

1. **SSH keys** — copy existing keys into `~/.ssh/` or generate new ones:
   ```bash
   ssh-keygen -t ed25519 -C "you@example.com"
   ```
   `~/.ssh` is a real directory, not a symlink into this repo, so keys written
   there stay out of the working tree.

2. **GitHub CLI** — authenticate:
   ```bash
   gh auth login
   ```

3. **App Store** — sign in, then re-run `brew bundle` if the `mas` entries were
   skipped during bootstrap.

4. **Neovim plugins** — bootstrap automatically on first launch.

5. **tmux plugins** — TPM and plugins auto-install on first tmux launch. To install new plugins after editing `tmux.conf` later, press `prefix + I`.

6. **Check your work** — `./doctor.sh` should come back clean.

---

## Updating

```bash
cd ~/Development/dotfiles
git pull
git submodule update --init --recursive
```

To re-stow after adding files to a package:

```bash
stow --restow --target="$HOME" <package>
```

---

## Adding New Dotfiles

1. Create a package directory mirroring `$HOME`:
   ```bash
   mkdir -p newpkg/.config/sometool
   mv ~/.config/sometool/config newpkg/.config/sometool/
   ```

2. Stow it:
   ```bash
   stow --restow --target="$HOME" newpkg
   ```

3. Commit.

If the tool needs installing too, add it to [`Brewfile`](Brewfile) (or
[`Brewfile.personal`](Brewfile.personal)) rather than to `bootstrap.sh` — that
keeps `doctor.sh` able to detect it as missing. Add the package name to
`STOW_PACKAGES` in [`lib.sh`](lib.sh); `bootstrap.sh` and `doctor.sh` both read
it from there.

---

## Uninstalling

Remove a single package's symlinks:

```bash
stow --delete --target="$HOME" <package>
```

Remove everything stowed by the bootstrap:

```bash
stow --delete --target="$HOME" zsh git tmux ssh nvim base16 claude
```

Only the symlinks are removed — source files in this repo remain untouched.
