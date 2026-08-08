#!/usr/bin/env bash
# Bootstrap a machine from this repo. Idempotent; safe to re-run.
#
#   ./bootstrap.sh                  interactive
#   ./bootstrap.sh --yes            assume defaults, never prompt
#   ./bootstrap.sh --personal       include Brewfile.personal (records the choice)
#   ./bootstrap.sh --no-personal    core packages only (records the choice)
#   ./bootstrap.sh --no-defaults    skip macos/defaults.sh
#   ./bootstrap.sh --check          report drift via doctor.sh and exit

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_FILE="$DOTFILES_DIR/.machine"

trap 'echo ">>> bootstrap failed at line $LINENO" >&2' ERR

# ---- Options ----
ASSUME_YES=0
APPLY_DEFAULTS=1
PERSONAL=""  # unset until resolved; "yes" or "no" once decided

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)      ASSUME_YES=1 ;;
    --personal)    PERSONAL=yes ;;
    --no-personal) PERSONAL=no ;;
    --no-defaults) APPLY_DEFAULTS=0 ;;
    --check)       exec bash "$DOTFILES_DIR/doctor.sh" ;;
    -h|--help)     sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)             echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

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

# ---- Resolve the machine tier ----
# An explicit flag wins and rewrites the record; otherwise reuse a previous
# answer; otherwise ask. Unattended runs default to core-only so they never
# pull down multi-gigabyte personal apps.
if [[ -n "$PERSONAL" ]]; then
  echo "PERSONAL=$PERSONAL" > "$MACHINE_FILE"
elif [[ -f "$MACHINE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$MACHINE_FILE"
  PERSONAL="${PERSONAL:-no}"
elif (( ASSUME_YES )) || [[ ! -t 0 ]]; then
  PERSONAL=no
  echo "PERSONAL=$PERSONAL" > "$MACHINE_FILE"
else
  echo ""
  read -rp ">>> Is this a personal machine? Installs media, games, and creative apps. [y/N] " _personal
  [[ "${_personal:-N}" =~ ^[Yy]$ ]] && PERSONAL=yes || PERSONAL=no
  echo "PERSONAL=$PERSONAL" > "$MACHINE_FILE"
fi
echo ">>> Machine tier: $([[ "$PERSONAL" == yes ]] && echo "core + personal" || echo "core only")"

# ---- Install dependencies ----
echo ">>> Installing dependencies..."
deps_failed=0

if [[ "$PLATFORM" == "macos" ]]; then
  # Xcode Command Line Tools — Homebrew needs them on a fresh Mac.
  if ! xcode-select -p &>/dev/null; then
    echo ">>> Installing Xcode Command Line Tools..."
    xcode-select --install || true
    echo ">>> Waiting for the Command Line Tools install to finish..."
    until xcode-select -p &>/dev/null; do sleep 10; done
  fi

  # Install Homebrew if missing.
  if ! command -v brew &>/dev/null; then
    echo ">>> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Ensure brew is on PATH for this session (a fresh install doesn't update
  # the current shell; a pre-existing install may be in a non-default location).
  if ! command -v brew &>/dev/null; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
        break
      fi
    done
    if ! command -v brew &>/dev/null; then
      echo ">>> Homebrew is not on PATH and was not found in either standard location." >&2
      exit 1
    fi
  fi

  # A missing App Store sign-in makes `mas` entries fail. Warn and carry on
  # rather than aborting before anything gets stowed.
  brew bundle --file="$DOTFILES_DIR/Brewfile" || deps_failed=1
  if [[ "$PERSONAL" == yes ]]; then
    brew bundle --file="$DOTFILES_DIR/Brewfile.personal" || deps_failed=1
  fi
  (( deps_failed )) && echo ">>> Warning: some packages failed to install; continuing." >&2
elif [[ "$PLATFORM" == "wsl" || "$PLATFORM" == "linux" ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y git curl stow zsh tmux neovim xclip ripgrep fd-find
fi

# ---- Init git submodules ----
echo ">>> Initializing git submodules..."
cd "$DOTFILES_DIR"
git submodule update --init --recursive

# ---- Clean up pre-existing absolute symlinks that confuse stow ----
# Stow 2.3.x bugs out when it finds absolute symlinks in the target dir.
# Remove known conflicts so stow only encounters its own relative links.
echo ">>> Cleaning up pre-existing symlinks..."
shopt -s nullglob
prezto_links=(.zprezto .bash_profile)
for rcfile in "$DOTFILES_DIR"/zprezto/runcoms/*; do
  rcname="${rcfile##*/}"
  [[ "$rcname" == "README.md" ]] && continue
  prezto_links+=(".$rcname")
done
for f in "${prezto_links[@]}"; do
  if [[ -L "$HOME/$f" ]] && [[ "$(readlink "$HOME/$f")" == /* ]]; then
    rm -f "$HOME/$f"
  fi
done

# ---- Stow shared packages ----
echo ">>> Stowing shared packages..."
cd "$DOTFILES_DIR"

# ssh goes first and on its own, so an unrelated conflict elsewhere can't leave
# ~/.ssh deleted between the unfold and the restow.
#
# --no-folding keeps ~/.ssh a real directory containing a symlinked config.
# Folded, ~/.ssh would itself be a symlink into this repo, and every key or
# known_hosts file written there would land in the git working tree.
stow_failed=0
if [[ -L "$HOME/.ssh" ]]; then
  echo ">>> Unfolding ~/.ssh (currently a symlink into the repo)..."
  stow --delete --target="$HOME" ssh
fi
stow --restow --no-folding --target="$HOME" ssh || stow_failed=1
[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"

STOW_PACKAGES=(zsh git tmux nvim base16 claude)
stow --restow --target="$HOME" "${STOW_PACKAGES[@]}" || stow_failed=1

if (( stow_failed )); then
  cat >&2 <<EOF

>>> stow refused to overwrite existing files in \$HOME.
    Options:
      1. Back up and remove the conflicting files, then re-run this script.
      2. Run: stow --adopt --target="\$HOME" <package>
         This pulls the existing files into the repo; review with 'git diff' before committing.
EOF
  exit 1
fi

# ---- Set up zprezto ----
echo ">>> Setting up zprezto..."
if [[ ! -e "$HOME/.zprezto" && ! -L "$HOME/.zprezto" ]]; then
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
shopt -u nullglob

# ---- Set zsh as default shell ----
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  echo ">>> Setting zsh as default shell..."
  if ! grep -qF "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH" || echo ">>> Warning: could not change default shell automatically; run 'chsh -s $ZSH_PATH' manually."
fi

# ---- macOS system defaults ----
applied_defaults=0
if [[ "$PLATFORM" == "macos" ]] && (( APPLY_DEFAULTS )); then
  if (( ASSUME_YES )) || [[ ! -t 0 ]]; then
    _apply_defaults=y
  else
    echo ""
    read -rp ">>> Apply macOS system defaults (Dock, Appearance, Keyboard, Finder)? [y/N] " _apply_defaults
  fi
  if [[ "${_apply_defaults:-N}" =~ ^[Yy]$ ]]; then
    bash "$DOTFILES_DIR/macos/defaults.sh"
    applied_defaults=1
  else
    echo ">>> Skipped. Run manually: bash $DOTFILES_DIR/macos/defaults.sh"
  fi
fi

# ---- Verify ----
if [[ "$(readlink -f "$HOME/.zshrc" 2>/dev/null)" != "$DOTFILES_DIR"/* ]]; then
  echo ">>> Warning: ~/.zshrc does not resolve into $DOTFILES_DIR." >&2
fi

# ---- Done ----
echo ""
echo "✓ Bootstrap complete."
if (( deps_failed )); then
  echo ""
  echo "⚠ Some packages failed to install. If mas entries failed, sign in to the"
  echo "  App Store and re-run: brew bundle --file=$DOTFILES_DIR/Brewfile"
fi
echo ""
echo "Next steps:"
echo "  1. Generate or copy your SSH keys to ~/.ssh/"
echo "  2. Re-authenticate GitHub CLI: gh auth login"
echo "  3. Restart your terminal or run: exec zsh"
echo "  4. Check for drift any time: ./doctor.sh"
if (( applied_defaults )); then
  echo "  5. Log out and back in for the Caps Lock → Control remap to take effect."
fi
