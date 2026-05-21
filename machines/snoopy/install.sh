#!/usr/bin/env bash
# Install dotfiles on snoopy (Proxmox VM, Linux — media services)
set -e
DOTFILES="$HOME/dotfiles"
MACHINE="$DOTFILES/machines/snoopy"
SECRETS="$HOME/dotfiles-secrets"

stow_home() {
    stow -d "$1" -t ~ --restow "${@:2}"
}

stow_root() {
    sudo stow -d "$1" -t / --restow "${@:2}"
}

echo "→ common (home)"
stow_home "$DOTFILES/common" btop claude git nvim ssh tmux yazi zsh

echo "→ snoopy (/etc — requires sudo)"
stow_root "$MACHINE" borgmatic ssh

if [ -d "$SECRETS" ]; then
    echo "→ secrets (home)"
    stow_home "$SECRETS/common"
    echo "→ secrets/snoopy (/etc — requires sudo)"
    stow_root "$SECRETS/machines/snoopy"
fi

echo "→ materializing evals.json (expand \$HOME)"
find "$DOTFILES/common/claude/.claude/skills" -name "evals.json" | while read -r tmpl; do
    rel="${tmpl#$DOTFILES/common/claude/}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    [[ -L "$dest" ]] && rm "$dest"
    tmp=$(mktemp) && sed "s|/Users/oliversteiner|$HOME|g" "$tmpl" > "$tmp" && mv "$tmp" "$dest"
done

echo "✓ done"
