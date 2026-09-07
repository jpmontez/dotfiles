# Core install list — every machine gets these, work or personal.
# Applied by `brew bundle` from bootstrap.sh.
# Re-run any time: `brew bundle --file=~/Development/dotfiles/Brewfile`
#
# Optional media/games/creative apps live in Brewfile.personal; bootstrap.sh
# asks once whether to include them and records the answer in .machine.
#
# `mas` entries require the App Store to be signed in first — `brew bundle`
# cannot sign in for you.

# Adopt apps already present at the install destination instead of erroring.
# Adoption needs the on-disk version to match the cask exactly; where it
# does not, the entry still fails and `brew bundle` reports it.
cask_args adopt: true

# ---- Shell & dotfile plumbing ----
brew "stow"    # symlink manager — deploys dotfiles packages into $HOME
brew "zsh"     # Homebrew zsh for a current release independent of macOS
brew "tmux"    # terminal multiplexer
brew "git"     # .gitconfig needs >= 2.38 (rebase.updateRefs, zdiff3); macOS ships Xcode's git

# ---- Editor & search ----
brew "neovim"          # editor (configured via nvim/ package)
brew "ripgrep"         # kickstart.nvim live-grep
brew "fd"              # kickstart.nvim file finder
brew "tree-sitter-cli" # nvim treesitter parser builds

# ---- Dev tooling ----
brew "gh"              # GitHub CLI — auth, PRs, issues
brew "node"
brew "shellcheck"      # lints this repo's scripts (also run in CI)
brew "xcodegen"        # generate .xcodeproj from a spec
brew "helm"
brew "k9s"
brew "kubernetes-cli"

# ---- macOS setup helpers ----
brew "dockutil"          # CLI for managing Dock icons (used by macos/defaults.sh)
brew "mas"               # Mac App Store CLI (used by the mas entries below)
brew "terminal-notifier" # aliased in zsh/.aliases

# ---- GUI apps ----
cask "ghostty"            # GPU-accelerated terminal emulator
cask "font-meslo-lg-nerd-font"  # Ghostty's configured font — falls back silently if absent
cask "claude-code@latest"
cask "claude"             # Claude desktop app
cask "google-chrome"
cask "docker-desktop"
cask "1password"
cask "jordanbaird-ice"    # Ice — menu bar manager
cask "sizeup"             # keyboard-driven window manager
cask "clipy"              # clipboard manager with history
cask "thaw"               # unquarantine downloaded apps
cask "keyboardcleantool"  # blocks input for keyboard cleaning
cask "hhkb"               # Happy Hacking Keyboard configurator
cask "logi-options+"      # Logitech input device config
cask "mullvad-vpn"        # privacy VPN
cask "pearcleaner"        # app uninstaller
cask "onyx"               # macOS maintenance and cleanup utility
cask "grandperspective"   # disk usage visualiser
cask "xcodes-app"         # Xcode version manager
cask "zoom"

# ---- Mac App Store ----
mas "Amphetamine",               id: 937984704   # prevent sleep / screen saver
mas "Balance Lock",              id: 1019371109  # keep audio balance centred
mas "Little Snitch Mini",        id: 1629008763  # outbound connection monitor
mas "Tomito",                    id: 1526042938  # pomodoro timer

# Safari extensions
mas "1Password for Safari",      id: 1569813296
mas "Wipr",                      id: 1662217862
mas "uBlock Origin Lite",        id: 6745342698
mas "Dark Reader for Safari",    id: 1438243180
mas "UnTrap",                    id: 1637438059
mas "SponsorBlock",              id: 1573461917
mas "Control Panel for Twitter", id: 1668516167
mas "Userscripts-Mac-App",       id: 1463298887
