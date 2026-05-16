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

`bootstrap.sh` detects your platform, installs dependencies (via `brew bundle` on macOS — see [`Brewfile`](Brewfile) — or `apt-get` on Linux/WSL), initializes submodules, symlinks every package, and sets zsh as the default shell. On macOS it also prompts to apply system defaults — see [macOS Configuration](#macos-configuration).

---

## What's Inside

### Stow packages

Each directory mirrors `$HOME` and is symlinked in by `stow`:

| Package   | Symlinks to `$HOME`               | Notes                          |
|-----------|-----------------------------------|--------------------------------|
| `zsh`     | `.zshrc`, `.zprofile`, `.aliases` | Shell config + prezto init     |
| `git`     | `.gitconfig`                      | Git identity and aliases       |
| `tmux`    | `.tmux.conf`                      | Prefix, vim keys, copy-paste   |
| `ssh`     | `.ssh/config`                     | SSH agent, ForwardAgent        |
| `nvim`    | `.config/nvim`                    | Submodule: kickstart.nvim      |
| `base16`  | `.config/base16-shell`            | Submodule: base16 color scheme |
| `zprezto` | `.zprezto`, `.zpreztorc`, etc.    | Manual symlinks via bootstrap  |

### Other files

| Path       | Purpose                                                 |
|------------|---------------------------------------------------------|
| `macos/`   | Optional macOS system defaults & login-item setup       |
| `Brewfile` | Declarative list of CLI tools, Cask apps, and App Store apps |

---

## macOS Configuration

`bootstrap.sh` prompts (`y/N`) to run `macos/defaults.sh` on macOS. You can also run it independently:

```bash
bash macos/defaults.sh
```

It configures, end to end:

- **Appearance** — auto-switching light/dark, hidden menu bar
- **Keyboard** — Caps Lock → Left Control (HID-level, all keyboards)
- **Trackpad** — tap to click
- **Dock** — left orientation, autohide, no recent apps, no MRU spaces; populated with a curated app list via `dockutil`
- **Menu bar** — Control Center icon and Now Playing visible
- **Clock** — AM/PM with day of week, no date
- **Third-party apps** — sensible defaults for SizeUp and Clipy
- **Launch Clipy** — builds an Automator launcher at `~/Applications/Launch Clipy.app` and registers it as a Login Item

After running, **log out and back in** for the Caps Lock remap to take effect. SizeUp, Mullvad VPN, and Amphetamine are installed by `brew bundle` but still need to be added as Login Items via System Settings → General → Login Items.

See [`macos/README.md`](macos/README.md) for details on each script and how the remap / Automator workflow is constructed.

---

## How It Works

Each stow package is a folder whose contents mirror `$HOME`. Running `stow --target="$HOME" <package>` creates symlinks in `$HOME` pointing back into this repo. For example, `zsh/.zshrc` becomes `~/.zshrc → ~/Development/dotfiles/zsh/.zshrc`.

This means:

- Editing a dotfile is just editing the file in this repo
- `git diff` always shows the live state of your config
- `stow --delete <package>` removes a package's symlinks

The repo must stay at `~/Development/dotfiles`. Stow's symlinks resolve relative to wherever the repo lives at the time `stow` runs — moving the directory later would break every link.

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
| Package manager    | Homebrew                             | apt                 |
| Clipboard in tmux  | `reattach-to-user-namespace pbcopy`  | `xclip`             |
| Homebrew init      | `.zprofile` (guarded by `uname`)     | Skipped             |
| GOROOT             | `brew --prefix golang`               | Omitted from PATH   |
| System defaults    | Prompted during bootstrap            | n/a                 |

Platform detection happens at the top of `bootstrap.sh` using `uname` and `/proc/version`. Shell configs use inline `[[ "$(uname)" == "Darwin" ]]` guards so a single set of dotfiles works on both platforms.

---

## Post-Install

1. **SSH keys** — copy existing keys into `~/.ssh/` or generate new ones:
   ```bash
   ssh-keygen -t ed25519 -C "you@example.com"
   ```

2. **GitHub CLI** — authenticate:
   ```bash
   gh auth login
   ```

3. **Neovim plugins** — bootstrap automatically on first launch.

4. **tmux plugins** — TPM and plugins auto-install on first tmux launch. To install new plugins after editing `tmux.conf` later, press `prefix + I`.

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

If the tool needs the bootstrap script to handle it (e.g. an additional `brew install`), update `bootstrap.sh` accordingly.

---

## Uninstalling

Remove a single package's symlinks:

```bash
stow --delete --target="$HOME" <package>
```

Remove everything stowed by the bootstrap:

```bash
stow --delete --target="$HOME" zsh git tmux ssh nvim base16
```

Only the symlinks are removed — source files in this repo remain untouched.
