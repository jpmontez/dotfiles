#!/usr/bin/env bash
# Bootstrap a machine from this repo. Idempotent; safe to re-run.

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

trap 'echo ">>> bootstrap failed at line $LINENO" >&2' ERR

usage() {
  cat <<'EOF'
Bootstrap a machine from this repo. Idempotent; safe to re-run.

  ./bootstrap.sh                  interactive
  ./bootstrap.sh --yes            assume defaults, never prompt
  ./bootstrap.sh --personal       include Brewfile.personal (records the choice)
  ./bootstrap.sh --no-personal    core packages only (records the choice)
  ./bootstrap.sh --no-defaults    skip macos/defaults.sh
EOF
}

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
    -h|--help)     usage; exit 0 ;;
    *)             echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# confirm <question> — true if the user says yes. Unattended runs (--yes or no
# tty) never prompt and take the default baked into each call site.
confirm() {
  local answer
  read -rp ">>> $1 [y/N] " answer
  [[ "${answer:-N}" =~ ^[Yy]$ ]]
}

interactive() { (( ! ASSUME_YES )) && [[ -t 0 ]]; }

echo ">>> Detected platform: $PLATFORM"

# ---- Resolve the machine tier ----
# An explicit flag wins; otherwise reuse a previous answer; otherwise ask.
# Unattended runs default to core-only so they never pull down multi-gigabyte
# personal apps. The resolved answer is always recorded for later runs.
if [[ -z "$PERSONAL" ]]; then
  if [[ -f "$MACHINE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$MACHINE_FILE"
    PERSONAL="${PERSONAL:-no}"
  elif interactive; then
    echo ""
    confirm "Is this a personal machine? Installs media, games, and creative apps." &&
      PERSONAL=yes || PERSONAL=no
  else
    PERSONAL=no
  fi
fi
echo "PERSONAL=$PERSONAL" > "$MACHINE_FILE"

tier="core only"
[[ "$PERSONAL" == yes ]] && tier="core + personal"
echo ">>> Machine tier: $tier"

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
  BREWFILES=("$DOTFILES_DIR/Brewfile")
  [[ "$PERSONAL" == yes ]] && BREWFILES+=("$DOTFILES_DIR/Brewfile.personal")
  for bf in "${BREWFILES[@]}"; do
    brew bundle --file="$bf" || deps_failed=1
  done
  (( deps_failed )) && echo ">>> Warning: some packages failed to install; continuing." >&2
else
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
# ~/.ssh deleted between the unfold and the restow. See lib.sh for why it needs
# SSH_STOW_OPTS.
stow_failed=0
if [[ -L "$HOME/.ssh" ]]; then
  echo ">>> Unfolding ~/.ssh (currently a symlink into the repo)..."
  stow --delete --target="$HOME" ssh
fi
stow --restow "${SSH_STOW_OPTS[@]}" --target="$HOME" ssh || stow_failed=1
[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"

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
  interactive && echo ""
  # Unattended runs apply them; interactive runs ask.
  if ! interactive || confirm "Apply macOS system defaults (Dock, Appearance, Keyboard, Finder)?"; then
    bash "$DOTFILES_DIR/macos/defaults.sh"
    applied_defaults=1
  else
    echo ">>> Skipped. Run manually: bash $DOTFILES_DIR/macos/defaults.sh"
  fi
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
