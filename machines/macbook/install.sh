#!/usr/bin/env bash
# Install dotfiles on macBook (macOS, arm64)
set -e
DOTFILES="$HOME/dotfiles"
SECRETS="$HOME/dotfiles-secrets"

stow_pkg() {
  local dir=$1; shift
  stow -d "$dir" -t ~ --restow "$@"
}

echo "→ common"
stow_pkg "$DOTFILES/common" nvim zsh tmux ghostty git btop yazi espanso helix ssh

echo "→ common-macos"
stow_pkg "$DOTFILES/common-macos" karabiner aerospace sketchybar swiftbar borders alfred bin

echo "→ claude (manual symlinks — not stow-managed yet)"
mkdir -p ~/.claude
ln -sf "$DOTFILES/common/claude/CLAUDE.md"    ~/.claude/CLAUDE.md
ln -sf "$DOTFILES/common/claude/settings.json" ~/.claude/settings.json
ln -sf "$DOTFILES/common/claude/skills"        ~/.claude/skills

if [ -d "$SECRETS" ]; then
  echo "→ secrets/common"
  stow_pkg "$SECRETS/common" "${@:-}"
  echo "→ secrets/common-macos"
  stow_pkg "$SECRETS/common-macos" "${@:-}"
fi

echo "✓ done"
