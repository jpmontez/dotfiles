# CLAUDE.md

Personal dotfiles managed with GNU stow. Full details: README.md.

## Structure
- Each top-level package directory (`zsh/`, `tmux/`, `claude/`, ...) mirrors
  `$HOME` and gets symlinked in by `stow`.
- `lib.sh` defines `STOW_PACKAGES`, shared paths, and platform detection —
  sourced by both `bootstrap.sh` and `doctor.sh`, never run directly.
- `bootstrap.sh` installs + stows everything (idempotent, safe to re-run).
  `doctor.sh` is read-only drift detection only — never edits anything.

## Conventions
- New dotfile: create/extend a package dir mirroring `$HOME`, then add the
  package name to `STOW_PACKAGES` in `lib.sh`. Don't hand-symlink or
  special-case it in `bootstrap.sh`.
- New tool dependency: add it to `Brewfile` (every machine) or
  `Brewfile.personal` (opt-in tier), not to `bootstrap.sh` — that's what lets
  `doctor.sh` detect it's missing.
- The repo must stay cloned at `~/Development/dotfiles`; stow's symlinks are
  relative to that path.
- Shell scripts: keep `shellcheck`-clean
  (`shellcheck bootstrap.sh doctor.sh lib.sh macos/*.sh`).

## Verifying changes
- `./doctor.sh` — read-only, exits 1 on drift. Run after any change to a
  stowed file, `lib.sh`, or a Brewfile.
- `zsh -n <file>` for zsh syntax; `bash -n <file>` for bash.
