# dotfiles

Personal dotfiles managed with [GNU stow](https://www.gnu.org/software/stow/). Works on macOS and WSL 2 (Ubuntu).

---

## Quick Start

```bash
$ git clone \
    --recurse-submodules \
    https://github.com/jpmontez/dotfiles.git ~/Development/dotfiles
$ cd ~/Development/dotfiles
$ ./bootstrap.sh
$ exec zsh
```

`bootstrap.sh` detects your platform, installs dependencies, initializes submodules, symlinks all packages, and sets zsh as the default shell.

---

## What's Inside

| Package   | Symlinks to `$HOME`              | Notes                          |
|-----------|----------------------------------|--------------------------------|
| `zsh`     | `.zshrc`, `.zprofile`, `.aliases` | Shell config + prezto init     |
| `git`     | `.gitconfig`                     | Git identity and aliases       |
| `tmux`    | `.tmux.conf`                     | Prefix, vim keys, copy-paste   |
| `ssh`     | `.ssh/config`                    | SSH agent, ForwardAgent        |
| `nvim`    | `.config/nvim`                   | Submodule: kickstart.nvim      |
| `base16`  | `.config/base16-shell`           | Submodule: base16 color scheme |
| `iterm2`  | `.config/iterm2`                 | macOS only                     |
| `zprezto` | `.zprezto`, `.zpreztorc`, etc.   | Manual symlinks via bootstrap  |

---

## How It Works

Each top-level directory is a **stow package** — a folder whose contents mirror the structure of `$HOME`. Running `stow --target="$HOME" <package>` creates symlinks in `$HOME` pointing back into this repo.

For example, `zsh/.zshrc` becomes `~/.zshrc -> ~/Development/dotfiles/zsh/.zshrc`.

This means:
- Editing a dotfile is just editing the file in this repo
- `git diff` always shows the live state of your config
- Removing a symlink is `stow --delete <package>`

The repo must stay at `~/Development/dotfiles` — stow's symlinks are relative to wherever the repo lives at the time `stow` runs. Moving the directory later would break all symlinks.

---

## Submodules

Three dependencies are tracked as git submodules:

| Submodule                      | Repo                                           |
|-------------------------------|------------------------------------------------|
| `zprezto`                     | `github.com/jpmontez/prezto`                   |
| `nvim/.config/nvim`           | `github.com/jpmontez/kickstart.nvim`           |
| `base16/.config/base16-shell` | `github.com/chriskempson/base16-shell`         |

After cloning, initialize them with:

```bash
git submodule update --init --recursive
```

`bootstrap.sh` does this automatically.

---

## Platform Support

| Feature            | macOS                              | WSL 2 / Linux                  |
|--------------------|------------------------------------|--------------------------------|
| Package manager    | Homebrew                           | apt                            |
| Clipboard in tmux  | `reattach-to-user-namespace pbcopy` | `xclip`                       |
| Homebrew init      | `.zprofile` (guarded by `uname`)   | Skipped                        |
| GOROOT             | `brew --prefix golang`             | Omitted from PATH              |
| iterm2 package     | Stowed                             | Skipped                        |

Platform detection happens at the top of `bootstrap.sh` using `uname` and `/proc/version`. Shell configs use inline `[[ "$(uname)" == "Darwin" ]]` guards so a single set of dotfiles works on both platforms.

---

## Post-Install Steps

After running `bootstrap.sh`:

1. **SSH keys** — copy or generate keys into `~/.ssh/`:
   ```bash
   ssh-keygen -t ed25519 -C "you@example.com"
   ```

2. **GitHub CLI** — re-authenticate:
   ```bash
   gh auth login
   ```

3. **Reload shell**:
   ```bash
   exec zsh
   ```

4. **Neovim plugins** — on first launch, kickstart.nvim will bootstrap itself automatically.

5. **tmux plugins** — on first launch, press `prefix + I` to install TPM plugins.

---

## Adding New Dotfiles

1. Create a new package directory matching the `$HOME` structure:
   ```bash
   mkdir -p newpkg/.config/sometool
   mv ~/.config/sometool/config newpkg/.config/sometool/config
   ```

2. Stow it:
   ```bash
   stow --restow --target="$HOME" newpkg
   ```

3. Commit:
   ```bash
   git add newpkg
   git commit -m "feat: add sometool dotfiles"
   ```
