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

# ---- Clean up pre-existing absolute symlinks that confuse stow ----
# Stow 2.3.x bugs out when it finds absolute symlinks in the target dir.
# Remove known conflicts so stow only encounters its own relative links.
echo ">>> Cleaning up pre-existing symlinks..."
for f in .zprezto .zlogin .zlogout .zpreztorc .zshenv .bash_profile; do
  if [[ -L "$HOME/$f" ]] && [[ "$(readlink "$HOME/$f")" == /* ]]; then
    rm -f "$HOME/$f"
  fi
done

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

# Create zprezto runcoms symlinks (skip any that already exist)
for rcfile in "$DOTFILES_DIR/zprezto/runcoms/"*; do
  [[ "${rcfile##*/}" == "README.md" ]] && continue
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
