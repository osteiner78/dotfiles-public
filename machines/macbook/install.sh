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
stow_home "$DOTFILES/common" btop claude espanso ghostty git helix nvim ssh tmux yazi zsh

echo "→ common-macos"
stow_home "$DOTFILES/common-macos" aerospace alfred bin borders karabiner sketchybar swiftbar

if [ -d "$SECRETS" ]; then
  echo "→ secrets/common"
  stow_home "$SECRETS/common"
  echo "→ secrets/common-macos"
  stow_home "$SECRETS/common-macos"
fi

echo "→ materializing evals.json (expand \$HOME)"
find "$DOTFILES/common/claude/.claude/skills" -name "evals.json" | while read -r tmpl; do
  rel="${tmpl#$DOTFILES/common/claude/}"
  dest="$HOME/$rel"
  mkdir -p "$(dirname "$dest")"
  # Remove stale symlink (if stow placed one before .stow-local-ignore existed)
  [[ -L "$dest" ]] && rm "$dest"
  tmp=$(mktemp) && sed "s|/Users/oliversteiner|$HOME|g" "$tmpl" > "$tmp" && mv "$tmp" "$dest"
done

echo "✓ done"
