#!/usr/bin/env bash
# Definitions shared by bootstrap.sh and doctor.sh — what this repo manages and
# which tier is active. Source this file; it defines things and runs nothing.
#
# Kept here so the two scripts can never disagree about the package set, the
# in-scope Brewfiles, or how the machine tier is read and written.
#
# Every variable here is consumed by the sourcing script, which shellcheck
# can't see from this file — hence the file-wide SC2034 exemption.
# shellcheck disable=SC2034

# Guard against double-sourcing.
[[ -n "${_DOTFILES_LIB_SH:-}" ]] && return 0
_DOTFILES_LIB_SH=1

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_FILE="$DOTFILES_DIR/.machine"

# Stow packages carrying no special options.
STOW_PACKAGES=(zsh git tmux nvim base16 claude)

# ssh is stowed on its own: --no-folding keeps ~/.ssh a real directory holding a
# symlinked config. Folded, ~/.ssh would itself be a symlink into this repo, and
# every key or known_hosts file written there would land in the working tree.
SSH_STOW_OPTS=(--no-folding)

# ---- Platform ----
if [[ "$(uname)" == "Darwin" ]]; then
  PLATFORM="macos"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  PLATFORM="wsl"
else
  PLATFORM="linux"
fi

# ---- Machine tier ----

# load_machine_tier — set PERSONAL from $MACHINE_FILE, defaulting to core-only
# when the file is absent or carries no value.
load_machine_tier() {
  # Reset first: the tier must come from the file, never from an inherited
  # PERSONAL in the caller's environment.
  PERSONAL=no
  if [[ -f "$MACHINE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$MACHINE_FILE"
  fi
  PERSONAL="${PERSONAL:-no}"
}

# save_machine_tier — record the resolved tier so later runs reuse the answer.
save_machine_tier() {
  echo "PERSONAL=$PERSONAL" > "$MACHINE_FILE"
}

# tier_label — human-readable name for the resolved tier.
tier_label() {
  [[ "$PERSONAL" == yes ]] && echo "core + personal" || echo "core only"
}

# load_brewfiles — populate BREWFILES with the Brewfiles this tier installs.
load_brewfiles() {
  BREWFILES=("$DOTFILES_DIR/Brewfile")
  [[ "$PERSONAL" == yes ]] && BREWFILES+=("$DOTFILES_DIR/Brewfile.personal")
  return 0
}
