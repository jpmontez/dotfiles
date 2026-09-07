#!/bin/bash
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "claude"
  exit 0
fi

IFS=$'\t' read -r MODEL DIR <<< "$(jq -r '[.model.display_name, .workspace.current_dir] | @tsv' <<< "$input")"
DIR_NAME=${DIR##*/}

if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
  echo "$MODEL  $DIR_NAME  $BRANCH"
else
  echo "$MODEL  $DIR_NAME"
fi
