# dotfiles

Personal dotfiles managed with [GNU stow](https://www.gnu.org/software/stow/). macOS first; Linux/WSL 2 gets the shell config and an apt fallback.

---

## Quick Start

```bash
git clone --recurse-submodules https://github.com/jpmontez/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles
./bootstrap.sh
exec zsh
```

`bootstrap.sh` installs dependencies (`brew bundle` on macOS, `apt-get` elsewhere), initializes submodules, stows every package, and sets zsh as the default shell. On macOS it also asks whether this is a personal machine and whether to apply system defaults.

| Flag | Effect |
|------|--------|
| `--yes`, `-y` | Assume defaults, never prompt. Implies core-only packages. |
| `--personal` | Install [`Brewfile.personal`](Brewfile.personal) too, and remember it |
| `--no-personal` | Core packages only, and remember it |
| `--no-defaults` | Skip `macos/defaults.sh` |

The repo must stay at `~/Development/dotfiles` — stow's symlinks resolve relative to wherever it lives when `stow` runs.

---

## What's Inside

Each package directory mirrors `$HOME` and is symlinked in by `stow`:

| Package   | Symlinks to `$HOME`               | Notes                          |
|-----------|-----------------------------------|--------------------------------|
| `zsh`     | `.zshrc`, `.zprofile`, `.aliases` | Shell config + prezto init     |
| `git`     | `.gitconfig`                      | Git identity and defaults      |
| `tmux`    | `.tmux.conf`                      | Prefix, vim keys, copy-paste   |
| `ghostty` | `.config/ghostty/config`          | Font, window size, bell behaviour |
| `ssh`     | `.ssh/config`                     | Stowed `--no-folding` — see [below](#why-ssh-is-stowed-differently) |
| `nvim`    | `.config/nvim`                    | Submodule: kickstart.nvim      |
| `base16`  | `.config/base16-shell`            | Submodule: base16 color scheme |
| `claude`  | `.claude/settings.json`           | Claude Code plugins, theme, model, notification hook |
| `zprezto` | `.zprezto`, `.zpreztorc`, etc.    | Manual symlinks via bootstrap  |

| Path                | Purpose                                                       |
|---------------------|---------------------------------------------------------------|
| `macos/`            | macOS system defaults & login items — see [macos/README.md](macos/README.md) |
| `Brewfile`          | Core CLI tools, casks, and App Store apps — every machine      |
| `Brewfile.personal` | Opt-in media, games, and creative apps                         |
| `doctor.sh`         | Read-only drift check                                          |
| `lib.sh`            | Paths, stow package list, and platform detection, shared by both scripts |

---

## Package Tiers

Two Brewfiles, so a work machine doesn't pull down Logic Pro. `bootstrap.sh`
asks once whether this is a personal machine and records the answer in
`.machine` (gitignored) as `PERSONAL=yes|no`; later runs reuse it. To change
your mind, re-run with `--personal` / `--no-personal`. `doctor.sh` reads the
same file, so a core-only machine is never nagged about personal apps.

Installing a tier on demand:

```bash
brew bundle --file=Brewfile.personal
```

`mas` entries need the App Store signed in first — `brew bundle` can't do that
for you. Bootstrap treats those failures as a warning, not fatal, so the rest of
the setup still completes.

DaVinci Resolve and the Blackmagic tools have no Homebrew cask; they're listed
in a comment block at the end of `Brewfile.personal`.

---

## macOS Configuration

Applied by bootstrap, or on demand:

```bash
bash macos/defaults.sh            # apply
bash macos/defaults.sh --check    # report drift, write nothing
```

Appearance, keyboard (including Caps Lock → Left Control), text substitution,
trackpad, Dock, Finder, menu bar, Touch ID for `sudo`, the
application firewall, and login items. The `SETTINGS` table at the top of
`macos/defaults.sh` is the authoritative list — both apply and `--check` read
it, so it can't drift from what's documented. FileVault is never changed
automatically; `doctor.sh` only reports it.

**Log out and back in** for the Caps Lock remap to take effect.

---

## Verifying

```bash
./doctor.sh
```

Read-only, exits 1 on drift. Covers packages (both directions), stow links,
macOS defaults, submodules, working tree, default shell, Xcode CLT, and
FileVault.

---

## Why `ssh` is stowed differently

When a package's directory has no counterpart in `$HOME`, stow "folds" it —
linking the whole directory rather than each file inside it. For `ssh` that
would make `~/.ssh` itself a symlink into this repo, so every key, `known_hosts`
entry, and control socket written there would land in the git working tree.

Bootstrap therefore stows `ssh` with `--no-folding`, leaving `~/.ssh` a real
directory (mode 700) holding a symlinked `config` and nothing else from the
repo. `doctor.sh` flags it if it ever folds back.

---

## Submodules

| Submodule                     | Repo                                   |
|-------------------------------|----------------------------------------|
| `zprezto`                     | `github.com/jpmontez/prezto`           |
| `nvim/.config/nvim`           | `github.com/jpmontez/kickstart.nvim`   |
| `base16/.config/base16-shell` | `github.com/chriskempson/base16-shell` |

`bootstrap.sh` initializes them; refresh with `git submodule update --init --recursive`.

---

## Post-Install

1. **SSH keys** — copy or generate into `~/.ssh/` (`ssh-keygen -t ed25519`). It's a real directory, so keys stay out of the working tree.
2. **GitHub CLI** — `gh auth login`.
3. **App Store** — sign in, then re-run `brew bundle` if `mas` entries were skipped.
4. **tmux plugins** — TPM auto-installs on first launch; `prefix + I` after adding plugins later.
5. **Check your work** — `./doctor.sh` should come back clean.

---

## Adding New Dotfiles

Create a package directory mirroring `$HOME`, move the file in, add the package
name to `STOW_PACKAGES` in [`lib.sh`](lib.sh), then:

```bash
stow --restow --target="$HOME" newpkg
```

If the tool needs installing too, add it to a Brewfile rather than to
`bootstrap.sh` — that keeps `doctor.sh` able to detect it as missing.

To remove a package's symlinks: `stow --delete --target="$HOME" <package>`.
Source files in this repo are untouched.
