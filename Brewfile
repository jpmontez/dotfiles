# Declarative macOS install list. Applied by `brew bundle` from bootstrap.sh.
# Re-run any time: `brew bundle --file=~/Development/dotfiles/Brewfile`

# ---- CLI tools ----
brew "stow"    # symlink manager — deploys dotfiles packages into $HOME
brew "zsh"     # Homebrew zsh for a current release independent of macOS
brew "tmux"    # terminal multiplexer
brew "neovim"  # editor (configured via nvim/ package)
brew "dockutil" # CLI for managing Dock icons (used by macos/defaults.sh)
brew "reattach-to-user-namespace"  # tmux pbcopy bridge
brew "gh"      # GitHub CLI — auth, PRs, issues
brew "mas"     # Mac App Store CLI

# ---- GUI apps ----
cask "ghostty"     # GPU-accelerated terminal emulator
cask "clipy"       # clipboard manager with history
cask "sizeup"      # keyboard-driven window manager
cask "mullvad-vpn" # privacy VPN

# ---- Mac App Store ----
mas "Amphetamine", id: 937984704  # prevent sleep / screen saver
