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
STOW_PACKAGES=(zsh git tmux ghostty nvim base16 claude)

# Claude Code rewrites ~/.claude/settings.json whenever a runtime option
# changes, which dirties the stowed copy on every /model switch. .gitattributes
# routes the file through this clean filter so git only sees the durable config;
# the filter command itself lives in each clone's git config, set by bootstrap.
# The filter keeps volatile keys out of commits; git still reports the file as
# modified though, because its refresh path hashes the file raw and only the
# diff machinery applies the filter. skip-worktree is what actually silences
# that — see CLAUDE.md for how to commit a deliberate change to the file.
CLAUDE_SETTINGS_FILE="claude/.claude/settings.json"
CLAUDE_SETTINGS_FILTER="filter.claude-settings.clean"
CLAUDE_SETTINGS_FILTER_CMD="$DOTFILES_DIR/claude-settings-clean.py"

# ssh is stowed on its own: --no-folding keeps ~/.ssh a real directory holding a
# symlinked config. Folded, ~/.ssh would itself be a symlink into this repo, and
# every key or known_hosts file written there would land in the working tree.
SSH_STOW_OPTS=(--no-folding)

if [[ "$(uname)" == "Darwin" ]]; then
  PLATFORM="macos"
else
  PLATFORM="linux"
fi
