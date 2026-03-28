# ---- Completion ----
autoload -Uz compinit
compinit -u

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

# https://github.com/sindresorhus/pure/issues/509#issuecomment-641001782
print() {
  [ 0 -eq $# -a "prompt_pure_precmd" = "${funcstack[-1]}" ] || builtin print "$@";
}

# ---- aliases ----
alias ll='ls -lah'
alias rsync='rsync -P'
alias tmux='tmux new-session -A -s main'
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

# ---- uv ----
export PATH="$HOME/.local/bin:$PATH"

# ---- Bun ----
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
