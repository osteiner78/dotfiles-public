#!/usr/bin/env bash
# Claude Code status line — mirrors oh-my-posh prompt segments
input=$(cat)

user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
display_dir="${cwd/#$home/\~}"

# Git branch (skip optional lock)
git_branch=""
if git_output=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch="$git_output"
elif git_output=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
  git_branch="$git_output"
fi

# Build status parts
printf "\033[0;33m%s@%s\033[0m" "$user" "$host"
printf " \033[0;34m%s\033[0m" "$display_dir"

if [ -n "$git_branch" ]; then
  printf " \033[0;32m %s\033[0m" "$git_branch"
fi

if [ -n "$model" ]; then
  printf " \033[0;36m%s\033[0m" "$model"
fi

if [ -n "$used" ]; then
  printf " \033[0;90mctx:%.0f%%\033[0m" "$used"
fi

printf "\n"
