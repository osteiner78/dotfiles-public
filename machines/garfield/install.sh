#!/usr/bin/env bash
# Install dotfiles on garfield (VPS, Linux)
set -e
DOTFILES="$HOME/dotfiles"
MACHINE="$DOTFILES/machines/garfield"
SECRETS="$HOME/dotfiles-secrets"

stow_home() {
  stow -d "$1" -t ~ --restow "${@:2}"
}

stow_root() {
  sudo stow -d "$1" -t / --restow "${@:2}"
}

echo "→ common (home)"
stow_home "$DOTFILES/common" zsh git tmux ssh btop nvim

echo "→ garfield (home)"
# none currently

echo "→ garfield (/etc — requires sudo)"
stow_root "$MACHINE" borgmatic caddy ssh

if [ -d "$SECRETS" ]; then
  echo "→ secrets (home)"
  stow_home "$SECRETS/common" "${@:-}"
  echo "→ secrets/garfield (/etc — requires sudo)"
  stow_root "$SECRETS/machines/garfield" "${@:-}"
fi

echo "✓ done"
