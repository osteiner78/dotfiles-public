#!/usr/bin/env bash
# Install dotfiles on raspi (Raspberry Pi — Home Assistant + Pi-hole)
set -e
DOTFILES="$HOME/dotfiles"
MACHINE="$DOTFILES/machines/raspi"
SECRETS="$HOME/dotfiles-secrets"

stow_home() {
    stow -d "$1" -t ~ --restow "${@:2}"
}

stow_root() {
    sudo stow -d "$1" -t / --restow "${@:2}"
}

echo "→ common (home)"
stow_home "$DOTFILES/common" zsh git ssh btop claude nvim tmux yazi

echo "→ raspi (/etc — requires sudo)"
stow_root "$MACHINE" borgmatic ssh

if [ -d "$SECRETS" ]; then
    echo "→ secrets/raspi (/etc — requires sudo)"
    stow_root "$SECRETS/machines/raspi"
fi

echo "✓ done"
