# Cross-Platform Dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate dotfiles from Dropbox + Python `dotfiles` package to a git repository managed with GNU stow, with clean macOS/WSL 2 platform compatibility.

**Architecture:** Per-tool stow packages live in the repo root; a single `bootstrap.sh` detects the platform, installs dependencies, initializes submodules, and runs stow. Platform-specific shell behavior is gated with `uname` checks inline.

**Tech Stack:** GNU stow, zsh + prezto, git submodules, bash (bootstrap script)

---

## Task 0: Move dotfiles to final destination

Symlinks created by stow will point to wherever the dotfiles directory lives at the time stow runs. Moving the directory after symlinking would break every symlink. Do this first.

**Files:** None — directory move only.

- [ ] **Step 1: Ensure ~/Development exists**

```bash
mkdir -p ~/Development
```

- [ ] **Step 2: Move the dotfiles directory out of Dropbox**

```bash
mv ~/Library/CloudStorage/Dropbox/dotfiles ~/Development/dotfiles
```

- [ ] **Step 3: Verify the move succeeded**

```bash
ls ~/Development/dotfiles
```

Expected: all existing dotfiles contents are present at the new path.

- [ ] **Step 4: Update the working directory for the rest of this plan**

All subsequent tasks assume the working directory is `~/Development/dotfiles`. From here on:

```bash
cd ~/Development/dotfiles
```

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Create | `.gitignore` | Exclude secrets, submodule inner `.git` dirs, OS artifacts |
| Create | `.gitmodules` | Submodule registry (managed by git submodule commands) |
| Create | `bootstrap.sh` | Single-command setup script |
| Create | `zsh/.zshrc` | Moved from `zshrc`; add `source ~/.aliases`; wrap GOROOT in macOS guard |
| Create | `zsh/.zprofile` | Moved from `zprofile`; wrap Homebrew in macOS guard |
| Create | `zsh/.aliases` | Moved from `aliases`; wrap `terminal-notifier` alias in macOS guard |
| Create | `git/.gitconfig` | Moved from `gitconfig` |
| Create | `tmux/.tmux.conf` | Moved from `tmux.conf`; replace pbcopy with `if-shell` platform detection |
| Create | `ssh/.ssh/config` | Moved from `ssh/config`; add `IgnoreUnknown UseKeychain` |
| Create | `nvim/.config/nvim/` | Submodule → `https://github.com/jpmontez/kickstart.nvim.git` |
| Create | `base16/.config/base16-shell/` | Submodule → `https://github.com/chriskempson/base16-shell.git` |
| Create | `iterm2/.config/iterm2/` | Moved from `config/iterm2/` |
| Delete | `config/argocd/` | No longer used |
| Delete | `irssi/` | No longer used |
| Delete | `config/rclone/` | No longer used |
| Delete | `config/.nvim/` | Legacy vim config, superseded |
| Delete | `dotfilesrc` | Python dotfiles package config, no longer needed |
| Delete | `bashrc`, `bash_profile` | Not tracked going forward |

---

## Task 1: Initialize git repository and .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Initialize the git repo**

```bash
cd ~/Development/dotfiles
git init
```

Expected output: `Initialized empty Git repository in .../dotfiles/.git/`

- [ ] **Step 2: Create .gitignore**

Create `~/Development/dotfiles/.gitignore` with:

```gitignore
# Secrets & credentials
ssh/.ssh/id_*
ssh/.ssh/known_hosts
ssh/.ssh/agent/
config/gh/hosts.yml

# Nested git repos (managed as submodules instead)
zprezto/.git
config/base16-shell/.git
config/nvim/.git
config/.nvim/

# OS artifacts
.DS_Store
*.swp
*~
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: initialize repo with .gitignore"
```

---

## Task 2: Delete unused directories and files

**Files:**
- Delete: `config/argocd/`, `irssi/`, `config/rclone/`, `config/.nvim/`, `dotfilesrc`, `bashrc`, `bash_profile`

- [ ] **Step 1: Delete removed directories**

```bash
cd ~/Development/dotfiles
rm -rf config/argocd irssi config/rclone config/.nvim
```

- [ ] **Step 2: Delete unused root files and stale symlinks**

```bash
rm -f dotfilesrc bashrc bash_profile
# Remove root-level zpreztorc and zshenv symlinks — bootstrap will recreate them
rm -f zpreztorc zshenv
```

- [ ] **Step 3: Clean up Dropbox conflicted copies**

```bash
find . -name "*conflicted copy*" -delete
find . -name "*.dropbox" -delete
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove unused dirs and Dropbox artifacts"
```

---

## Task 3: Reorganize files into stow packages

**Files:**
- Create: `zsh/`, `git/`, `tmux/`, `ssh/.ssh/`, `nvim/.config/`, `base16/.config/`, `iterm2/.config/`

- [ ] **Step 1: Create zsh package**

```bash
cd ~/Development/dotfiles
mkdir -p zsh
cp zshrc zsh/.zshrc
cp zprofile zsh/.zprofile
cp aliases zsh/.aliases
rm zshrc zprofile aliases
```

- [ ] **Step 2: Create git package**

```bash
mkdir -p git
cp gitconfig git/.gitconfig
rm gitconfig
```

- [ ] **Step 3: Create tmux package**

```bash
mkdir -p tmux
cp tmux.conf tmux/.tmux.conf
rm tmux.conf
```

- [ ] **Step 4: Create ssh package**

The stow package and the existing directory share the name `ssh/`, so we use a temp location to avoid a collision:

```bash
mkdir -p /tmp/ssh_stow/.ssh
cp ssh/config /tmp/ssh_stow/.ssh/config
rm -rf ssh
mv /tmp/ssh_stow ssh
```

- [ ] **Step 5: Create iterm2 package**

```bash
mkdir -p iterm2/.config
mv config/iterm2 iterm2/.config/iterm2
```

- [ ] **Step 6: Create nvim package directory**

```bash
mkdir -p nvim/.config
```

The `nvim/.config/nvim/` directory will be populated in Task 5 when the submodule is added.

- [ ] **Step 7: Create base16 package directory and remove old config/base16-shell**

```bash
mkdir -p base16/.config
# Remove old base16-shell dir — will be re-added as submodule at new path in Task 5
rm -rf config/base16-shell
```

The `base16/.config/base16-shell/` directory will be populated in Task 5 when the submodule is added.

- [ ] **Step 8: Clean up remaining config/ subdirectories**

These directories are minor tool configs not included in the stow design:

```bash
rm -rf config/htop config/wslu config/gtk-2.0 config/.mono config/configstore config/cagent config/git
rm -rf config/gh "config/Transmission Remote GUI"
rmdir config
```

If `rmdir` fails, `config/` still has unexpected contents — investigate before proceeding.

- [ ] **Step 9: Verify structure looks correct**

```bash
ls -la ~/Development/dotfiles/
```

Expected output includes: `zsh/  git/  tmux/  ssh/  iterm2/  nvim/  base16/  docs/  bootstrap.sh (not yet)`

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "chore: reorganize files into stow packages"
```

---

## Task 4: Apply platform detection fixes

**Files:**
- Modify: `zsh/.zshrc`
- Modify: `zsh/.zprofile`
- Modify: `zsh/.aliases`
- Modify: `tmux/.tmux.conf`
- Modify: `ssh/.ssh/config`

- [ ] **Step 1: Update zsh/.zprofile — wrap Homebrew in macOS guard**

Replace the contents of `zsh/.zprofile` with:

```zsh
# https://github.com/openai/codex/issues/6960
if [[ "$(uname)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi
```

- [ ] **Step 2: Update zsh/.zshrc — wrap GOROOT in macOS guard and source .aliases**

The GOROOT line calls `brew --prefix golang` which does not exist on Linux. Replace the Go section and add `.aliases` sourcing. Full updated `zsh/.zshrc`:

```zsh
# ---- Completion ----
autoload -Uz compinit
compinit -u

# ---- base16 shell ----
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        source "$BASE16_SHELL/profile_helper.sh"

# ---- prezto ----
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# ---- prompt / Pure tweaks ----
prompt_newline='%667v '
PROMPT=" $PROMPT"

# https://github.com/sindresorhus/pure/issues/509#issuecomment-641001782
print() {
  [ 0 -eq $# -a "prompt_pure_precmd" = "${funcstack[-1]}" ] || builtin print "$@";
}

# ---- aliases ----
alias ll='ls -lah'
alias rsync='rsync -P'
alias tmux='tmux new-session -A -s main'
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"

# ---- Go ----
export GOPATH="${HOME}/Development/go"
if [[ "$(uname)" == "Darwin" ]]; then
  export GOROOT="$(brew --prefix golang)/libexec"
  path=("${GOPATH}/bin" "${GOROOT}/bin" $path)
else
  path=("${GOPATH}/bin" $path)
fi

# ---- Python ----
path=("${HOME}/.local/bin" $path)

# ---- uv ----
export PATH="$HOME/.local/bin:$PATH"

# ---- Bun ----
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
```

- [ ] **Step 3: Update zsh/.aliases — wrap macOS-specific alias**

Replace the contents of `zsh/.aliases` with:

```zsh
alias ll='ls -lah'

if [[ "$(uname)" == "Darwin" ]]; then
  alias terminal-notifier='reattach-to-user-namespace terminal-notifier'
fi
```

- [ ] **Step 4: Update tmux/.tmux.conf — replace hardcoded pbcopy lines**

Replace lines 39 and 43 (the two `reattach-to-user-namespace` lines) in `tmux/.tmux.conf`:

Old:
```tmux
bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"

# Update default binding of `Enter` to also use copy-pipe
unbind -T copy-mode-vi Enter
bind-key -T copy-mode-vi Enter send -X copy-pipe "reattach-to-user-namespace pbcopy"
```

New:
```tmux
if-shell "uname | grep -q Darwin" \
  "bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel 'reattach-to-user-namespace pbcopy'" \
  "bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'"

# Update default binding of `Enter` to also use copy-pipe
unbind -T copy-mode-vi Enter
if-shell "uname | grep -q Darwin" \
  "bind-key -T copy-mode-vi Enter send -X copy-pipe 'reattach-to-user-namespace pbcopy'" \
  "bind-key -T copy-mode-vi Enter send -X copy-pipe 'xclip -in -selection clipboard'"
```

- [ ] **Step 5: Update ssh/.ssh/config — add IgnoreUnknown at top**

Replace the contents of `ssh/.ssh/config` with:

```
IgnoreUnknown UseKeychain

Host *
    AddKeysToAgent yes
    ForwardAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
```

- [ ] **Step 6: Commit**

```bash
git add zsh/.zshrc zsh/.zprofile zsh/.aliases tmux/.tmux.conf ssh/.ssh/config
git commit -m "feat: add platform detection for macOS/WSL compatibility"
```

---

## Task 5: Add git submodules

**Files:**
- Create: `zprezto/` (submodule)
- Create: `nvim/.config/nvim/` (submodule)
- Create: `base16/.config/base16-shell/` (submodule)
- Create: `.gitmodules`

Note: The existing `zprezto/` and `config/nvim/` directories contain `.git` directories, which means they are already local git repos. They need to be removed and re-added as proper submodules so git tracks them as references, not nested repos.

- [ ] **Step 1: Remove existing zprezto directory**

```bash
cd ~/Development/dotfiles
rm -rf zprezto
```

- [ ] **Step 2: Add zprezto as a submodule**

```bash
git submodule add https://github.com/jpmontez/prezto.git zprezto
git submodule update --init --recursive zprezto
```

Expected: zprezto cloned into `zprezto/` with all nested submodules.

- [ ] **Step 3: Remove existing config/nvim directory**

`config/base16-shell/` was already removed in Task 3. Only `config/nvim/` needs removing here:

```bash
rm -rf config/nvim
```

- [ ] **Step 4: Add nvim as a submodule in its stow package location**

```bash
git submodule add https://github.com/jpmontez/kickstart.nvim.git nvim/.config/nvim
```

Expected: kickstart.nvim cloned into `nvim/.config/nvim/`.

- [ ] **Step 5: Add base16-shell as a submodule in its stow package location**

```bash
git submodule add https://github.com/chriskempson/base16-shell.git base16/.config/base16-shell
```

Expected: base16-shell cloned into `base16/.config/base16-shell/`.

- [ ] **Step 6: Verify .gitmodules was created correctly**

```bash
cat .gitmodules
```

Expected output:
```
[submodule "zprezto"]
	path = zprezto
	url = https://github.com/jpmontez/prezto.git
[submodule "nvim/.config/nvim"]
	path = nvim/.config/nvim
	url = https://github.com/jpmontez/kickstart.nvim.git
[submodule "base16/.config/base16-shell"]
	path = base16/.config/base16-shell
	url = https://github.com/chriskempson/base16-shell.git
```

- [ ] **Step 7: Commit**

```bash
git add .gitmodules zprezto nvim/.config/nvim base16/.config/base16-shell
git commit -m "chore: add zprezto, nvim, and base16-shell as git submodules"
```

---

## Task 6: Write bootstrap.sh

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Write bootstrap.sh**

Create `~/Development/dotfiles/bootstrap.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Platform detection ----
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
  PLATFORM="macos"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  PLATFORM="wsl"
else
  PLATFORM="linux"
fi

echo ">>> Detected platform: $PLATFORM"

# ---- Install dependencies ----
echo ">>> Installing dependencies..."

if [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew &>/dev/null; then
    echo ">>> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install stow zsh tmux neovim
elif [[ "$PLATFORM" == "wsl" || "$PLATFORM" == "linux" ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y stow zsh tmux neovim xclip
fi

# ---- Init git submodules ----
echo ">>> Initializing git submodules..."
cd "$DOTFILES_DIR"
git submodule update --init --recursive

# ---- Stow shared packages ----
echo ">>> Stowing shared packages..."
cd "$DOTFILES_DIR"
stow --restow --target="$HOME" zsh git tmux ssh nvim base16

# ---- Stow platform-specific packages ----
if [[ "$PLATFORM" == "macos" ]]; then
  echo ">>> Stowing macOS packages..."
  stow --restow --target="$HOME" iterm2
fi

# ---- Set up zprezto ----
echo ">>> Setting up zprezto..."
if [[ ! -L "$HOME/.zprezto" ]]; then
  ln -s "$DOTFILES_DIR/zprezto" "$HOME/.zprezto"
fi

# Create zprezto runcoms symlinks (skip README and any that already exist)
setopt EXTENDED_GLOB 2>/dev/null || true
for rcfile in "$HOME/.zprezto/runcoms/"^README.md; do
  target="$HOME/.${rcfile##*/}"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    ln -s "$rcfile" "$target"
  fi
done

# ---- Set zsh as default shell ----
ZSH_PATH="$(which zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  echo ">>> Setting zsh as default shell..."
  if ! grep -qF "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH"
fi

# ---- Done ----
echo ""
echo "✓ Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Generate or copy your SSH keys to ~/.ssh/"
echo "  2. Re-authenticate GitHub CLI: gh auth login"
echo "  3. Restart your terminal or run: exec zsh"
```

- [ ] **Step 2: Make bootstrap.sh executable**

```bash
chmod +x ~/Development/dotfiles/bootstrap.sh
```

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "feat: add bootstrap.sh for automated setup on macOS and WSL"
```

---

## Task 7: Verify stow on macOS

- [ ] **Step 1: Dry run stow to check for conflicts before symlinking**

```bash
cd ~/Development/dotfiles
stow --simulate --target="$HOME" zsh git tmux ssh nvim base16
```

Expected: no output means no conflicts. If there are conflicts, stow will report which existing files are in the way — back those up before proceeding.

- [ ] **Step 2: Remove existing symlinks/files that the Python dotfiles package created**

Check what the old symlinks point to:

```bash
ls -la ~/.zshrc ~/.zprofile ~/.aliases ~/.gitconfig ~/.tmux.conf ~/.ssh/config 2>/dev/null
```

If any of these point into the old Dropbox location (e.g., `~/Dropbox/dotfiles/zshrc`), remove them:

```bash
rm -f ~/.zshrc ~/.zprofile ~/.aliases ~/.gitconfig ~/.tmux.conf
rm -f ~/.ssh/config
```

- [ ] **Step 3: Run stow**

```bash
cd ~/Development/dotfiles
stow --restow --target="$HOME" zsh git tmux ssh nvim base16 iterm2
```

- [ ] **Step 4: Verify symlinks were created**

```bash
ls -la ~/.zshrc ~/.zprofile ~/.aliases ~/.gitconfig ~/.tmux.conf ~/.ssh/config
```

Each should be a symlink pointing into `~/Development/dotfiles/<package>/`.

- [ ] **Step 5: Verify shell loads without errors**

```bash
zsh -c "source ~/.zshrc && echo 'zshrc OK'"
```

Expected: `zshrc OK` with no errors.

- [ ] **Step 6: Commit any fixes discovered during verification**

If any issues were found and fixed during verification:

```bash
git add -A
git commit -m "fix: resolve stow conflicts found during verification"
```

---

## Task 8: Create GitHub repository and push

- [ ] **Step 1: Create a new public GitHub repository named `dotfiles`**

```bash
gh repo create dotfiles --public --source=. --remote=origin --push
```

Expected: repository created at `https://github.com/jpmontez/dotfiles` and initial commits pushed.

- [ ] **Step 2: Verify the repository is clean and complete**

```bash
git status
git log --oneline
```

Expected: clean working tree, commit history showing all tasks.

- [ ] **Step 3: Verify submodules are registered correctly on GitHub**

```bash
cat .gitmodules
git submodule status
```

Expected: all three submodules listed with their commit hashes.
