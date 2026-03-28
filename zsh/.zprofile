# https://github.com/openai/codex/issues/6960
if [[ "$(uname)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi
