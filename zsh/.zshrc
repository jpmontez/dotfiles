# ---- PATH dedupe ----
typeset -U path PATH

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
export VISUAL=nvim
# -F: quit if one screen, -R: pass raw color, -X: don't clear screen on exit
export PAGER='less -FRX'
# man pages in nvim: base16 colours, K / Ctrl-] follow references
export MANPAGER='nvim +Man!'
export CLAUDE_CODE_NO_FLICKER=1

# ---- aliases / wrappers ----
# Attach to or create the 'main' session when invoked bare; pass through otherwise.
# -D detaches any other client first: with window-size latest, a stale smaller
# client (old tab/split) would otherwise pin windows to its size.
tmux() {
  if (( $# == 0 )); then
    command tmux new-session -A -D -s main
  else
    command tmux "$@"
  fi
}

# Resume the most recent Claude Code session for the current directory when
# invoked bare, falling back to a fresh session if none exists.
# Claude Code stores sessions under ~/.claude/projects/<pwd>/ with every
# non-alphanumeric character (/, ., space, ...) replaced by '-', which
# ${PWD//[^[:alnum:]]/-} reproduces; (N) suppresses the glob error on no match.
claude() {
  if (( $# == 0 )); then
    local sessions=("$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}"/*.jsonl(N))
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

# ---- fzf ----
# Ctrl-R history, Ctrl-T files, Alt-C cd (Alt needs Ghostty's
# macos-option-as-alt). Sourced after prezto so its Ctrl-R binding wins.
# fd honours .gitignore; --tmux opens pickers in a tmux popup (ignored outside
# tmux); --color=16 uses the ANSI palette, like tmux's styling.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--tmux 80%,60% --color=16'
(( $+commands[fzf] )) && source <(fzf --zsh)

# ---- Go ----
export GOPATH="${HOME}/Development/go"
path=("${GOPATH}/bin" $path)

# ---- Python ----
path=("${HOME}/.local/bin" $path)

# ---- Bun ----
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" $path)
