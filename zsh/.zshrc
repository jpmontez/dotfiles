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
export CLAUDE_CODE_NO_FLICKER=1

# ---- aliases / wrappers ----
# Attach to or create the 'main' session when invoked bare; pass through otherwise.
tmux() {
  if (( $# == 0 )); then
    command tmux new-session -A -s main
  else
    command tmux "$@"
  fi
}

# Resume the most recent Claude Code session for the current directory when
# invoked bare, falling back to a fresh session if none exists.
# Claude Code stores sessions under ~/.claude/projects/<pwd-with-/-as--> /;
# ${PWD//\//-} encodes the path, and (N) suppresses the glob error on no match.
claude() {
  if (( $# == 0 )); then
    local sessions=("$HOME/.claude/projects/${PWD//\//-}"/*.jsonl(N))
    if (( ${#sessions} > 0 )); then
      command claude --continue
    else
      command claude
    fi
  else
    command claude "$@"
  fi
}
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"

# ---- Go ----
export GOPATH="${HOME}/Development/go"
path=("${GOPATH}/bin" $path)

# ---- Python ----
path=("${HOME}/.local/bin" $path)

# ---- Bun ----
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" $path)
