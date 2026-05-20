#!/usr/bin/env bash
# Install dotfiles on macBook (macOS, arm64)
set -e
DOTFILES="$HOME/dotfiles"
SECRETS="$HOME/dotfiles-secrets"

stow_home() {
  local dir=$1; shift
  stow -d "$dir" -t ~ --restow "$@"
}

echo "→ common"
stow_home "$DOTFILES/common" nvim zsh tmux ghostty git btop yazi espanso helix ssh claude

echo "→ common-macos"
stow_home "$DOTFILES/common-macos" karabiner aerospace sketchybar swiftbar borders alfred bin

if [ -d "$SECRETS" ]; then
  echo "→ secrets/common"
  stow_home "$SECRETS/common"
  echo "→ secrets/common-macos"
  stow_home "$SECRETS/common-macos"
fi

echo "✓ done"
