#!/usr/bin/env bash
# Definitions shared by bootstrap.sh and doctor.sh — what this repo manages.
# Source this file; it defines things and runs nothing.
#
# Kept here so the two scripts can never disagree about the package set or
# where the machine tier is recorded.
#
# Every variable here is consumed by the sourcing script, which shellcheck
# can't see from this file — hence the file-wide SC2034 exemption.
# shellcheck disable=SC2034

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_FILE="$DOTFILES_DIR/.machine"

# Stow packages carrying no special options.
STOW_PACKAGES=(zsh git tmux ghostty nvim claude)

# ssh is stowed on its own: --no-folding keeps ~/.ssh a real directory holding a
# symlinked config. Folded, ~/.ssh would itself be a symlink into this repo, and
# every key or known_hosts file written there would land in the working tree.
SSH_STOW_OPTS=(--no-folding)

# Private repo holding Claude Code's OKF knowledge bundles. bootstrap clones it
# when the GitHub account can see it; doctor checks the clone's origin. Nothing
# in it is executed or linked into place. Optional: a fork without access skips
# it.
KNOWLEDGE_REPO="jpmontez/knowledge"
KNOWLEDGE_DIR="$HOME/Development/knowledge"

if [[ "$(uname)" == "Darwin" ]]; then
  PLATFORM="macos"
else
  PLATFORM="linux"
fi
