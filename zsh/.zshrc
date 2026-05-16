# ---- PATH dedupe ----
typeset -U path PATH

# ---- base16 shell ----
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        source "$BASE16_SHELL/profile_helper.sh"

# ---- prezto ----
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# ---- prompt / Pure tweaks ----
prompt_newline='%667v '
PROMPT=" $PROMPT"

# Suppress Pure's empty pre-prompt newline so the blank line above the prompt isn't eaten.
# https://github.com/sindresorhus/pure/issues/509#issuecomment-641001782
print() {
  [ 0 -eq $# -a "prompt_pure_precmd" = "${funcstack[-1]}" ] || builtin print "$@";
}

# ---- environment ----
export COLORTERM=truecolor
export EDITOR=nvim
# -F: quit if one screen, -R: pass raw color, -X: don't clear screen on exit
export PAGER='less -FRX'

# ---- aliases ----
alias ll='ls -lah'
alias rsync='rsync -P'

# Attach to or create the 'main' session when invoked bare; pass through otherwise.
tmux() {
  if (( $# == 0 )); then
    command tmux new-session -A -s main
  else
    command tmux "$@"
  fi
}

# Resume the most recent session in the current directory when invoked bare.
claude() {
  if (( $# == 0 )); then
    command claude --continue
  else
    command claude "$@"
  fi
}
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"

# ---- Go ----
export GOPATH="${HOME}/Development/go"
if [[ "$(uname)" == "Darwin" ]]; then
  export GOROOT="$(brew --prefix golang)/libexec"
  path=("${GOPATH}/bin" "${GOROOT}/bin" $path)
else
  path=("${GOPATH}/bin" $path)
fi

# ---- Python ----
path=("${HOME}/.local/bin" $path)

# ---- Bun ----
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" $path)
