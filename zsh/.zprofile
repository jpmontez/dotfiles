# https://github.com/openai/codex/issues/6960#issuecomment-3556921714
if [[ "$(uname)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# Set once at login so non-interactive subshells (e.g. GUI-launched processes) inherit it.
export CLAUDE_CODE_NO_FLICKER=1
