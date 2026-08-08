#!/usr/bin/env bash
# Report drift between this repo and the live machine. Read-only — makes no
# changes. Exits 1 if anything has drifted.
#
#   ./doctor.sh

set -uo pipefail  # deliberately no -e: every check runs even if one fails

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_FILE="$DOTFILES_DIR/.machine"

drift=0
section() { echo ""; echo "== $1"; }
ok()   { echo "  ✓ $*"; }
bad()  { drift=1; echo "  ✗ $*"; }
hint() { echo "      → $*"; }

PERSONAL=no
if [[ -f "$MACHINE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$MACHINE_FILE"
  PERSONAL="${PERSONAL:-no}"
fi

# ---------------------------------------------------------------------------
section "Packages (tier: $([[ "$PERSONAL" == yes ]] && echo "core + personal" || echo "core only"))"
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  bad "Homebrew not installed"
  hint "./bootstrap.sh"
else
  BREWFILES=("$DOTFILES_DIR/Brewfile")
  [[ "$PERSONAL" == yes ]] && BREWFILES+=("$DOTFILES_DIR/Brewfile.personal")

  for bf in "${BREWFILES[@]}"; do
    if missing="$(brew bundle check --file="$bf" --verbose 2>&1 | grep '^→' || true)"; then
      if [[ -n "$missing" ]]; then
        bad "${bf##*/}: missing entries"
        while IFS= read -r line; do echo "      $line"; done <<<"$missing"
        hint "brew bundle install --file=$bf"
      else
        ok "${bf##*/}: all entries installed"
      fi
    fi
  done

  # `brew bundle` accepts a single --file, so concatenate the in-scope
  # Brewfiles to check the reverse direction. cleanup without --force only
  # lists; it removes nothing.
  combined="$(mktemp)"
  cat "${BREWFILES[@]}" > "$combined"
  # Keep only the "Would uninstall …" sections; the trailing `brew cleanup`
  # section is about stale download caches, not package drift.
  extras="$(brew bundle cleanup --file="$combined" 2>/dev/null |
    awk '/^Would uninstall/ {f=1; print; next} /^Would `brew cleanup`/ {f=0} f && NF' || true)"
  rm -f "$combined"
  if [[ -n "$extras" ]]; then
    bad "installed but not listed in any in-scope Brewfile"
    while IFS= read -r line; do echo "      $line"; done <<<"$extras"
    hint "add them to Brewfile / Brewfile.personal, or uninstall them"
  else
    ok "no unlisted packages"
  fi
fi

# ---------------------------------------------------------------------------
section "Stow links"
# ---------------------------------------------------------------------------
if ! command -v stow &>/dev/null; then
  bad "stow not installed"
else
  # ~/.ssh must be a real directory. As a folded symlink into the repo, any
  # key or known_hosts written there lands in the git working tree.
  # Tildes below are display text, not paths.
  # shellcheck disable=SC2088
  if [[ -L "$HOME/.ssh" ]]; then
    bad "~/.ssh is a symlink into the repo (stow folded it)"
    hint "./bootstrap.sh  — unfolds it and restows with --no-folding"
  else
    ok "~/.ssh is a real directory"
    perms="$(stat -f '%Lp' "$HOME/.ssh" 2>/dev/null || echo "?")"
    if [[ "$perms" == "700" ]]; then
      ok "~/.ssh permissions are 700"
    else
      bad "~/.ssh permissions are $perms, want 700"
      hint "chmod 700 ~/.ssh"
    fi
  fi

  for pkg in zsh git tmux ssh nvim base16 claude; do
    args=(--dir="$DOTFILES_DIR" --no --restow --target="$HOME" "$pkg")
    [[ "$pkg" == ssh ]] && args+=(--no-folding)
    # stow always emits a simulation-mode banner under --no; drop it so only
    # real conflicts and pending link changes remain.
    out="$(stow "${args[@]}" 2>&1 | grep -v '^WARNING: in simulation mode' || true)"
    if [[ -z "$out" ]]; then
      ok "$pkg"
    else
      bad "$pkg is not fully stowed"
      while IFS= read -r line; do [[ -n "$line" ]] && echo "      $line"; done <<<"$out"
      hint "./bootstrap.sh, or stow --adopt --target=\"\$HOME\" $pkg"
    fi
  done
fi

# ---------------------------------------------------------------------------
section "macOS defaults"
# ---------------------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  ok "skipped (not macOS)"
else
  # Capture first: defaults.sh --check exits 1 on drift, and under pipefail a
  # `... | grep` test would read that as "no drift found".
  defaults_out="$(bash "$DOTFILES_DIR/macos/defaults.sh" --check 2>&1 | grep '✗' || true)"
  if [[ -n "$defaults_out" ]]; then
    drift=1
    while IFS= read -r line; do echo "  ${line#"${line%%[![:space:]]*}"}"; done <<<"$defaults_out"
    hint "bash macos/defaults.sh"
  else
    ok "all settings match"
  fi
fi

# ---------------------------------------------------------------------------
section "Repo"
# ---------------------------------------------------------------------------
sub_status="$(cd "$DOTFILES_DIR" && git submodule status 2>/dev/null)"
if grep -qE '^[+-]' <<<"$sub_status"; then
  bad "submodules out of sync"
  while IFS= read -r line; do
    [[ "$line" =~ ^[+-] ]] && echo "      $line"
  done <<<"$sub_status"
  hint "git submodule update --init --recursive"
else
  ok "submodules at recorded commits"
fi

if [[ -n "$(cd "$DOTFILES_DIR" && git status --porcelain 2>/dev/null)" ]]; then
  bad "working tree is dirty"
  hint "git -C $DOTFILES_DIR status"
else
  ok "working tree clean"
fi

# ---------------------------------------------------------------------------
section "Environment"
# ---------------------------------------------------------------------------
zsh_path="$(command -v zsh || true)"
if [[ "$SHELL" == "$zsh_path" ]]; then
  ok "default shell is $SHELL"
else
  bad "default shell is $SHELL, want $zsh_path"
  hint "chsh -s $zsh_path"
fi

if [[ "$(uname)" == "Darwin" ]]; then
  if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools at $(xcode-select -p)"
  else
    bad "Xcode Command Line Tools not installed"
    hint "xcode-select --install"
  fi

  if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
    ok "FileVault is on"
  else
    bad "FileVault is off"
    hint "System Settings → Privacy & Security → FileVault"
  fi
fi

# ---------------------------------------------------------------------------
echo ""
if (( drift )); then
  echo "✗ Drift detected — see above."
  exit 1
fi
echo "✓ Machine matches the repo."
