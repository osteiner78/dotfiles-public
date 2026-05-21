#!/usr/bin/env bash
# Unified dotfiles installer — auto-detects machine from hostname/uname.
# Override: MACHINE=<name> ./install.sh [extra-packages...]
# Available machines: macbook  garfield  raspi  snoopy  vm
# vm example: MACHINE=vm ./install.sh claude helix
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
SECRETS="$HOME/dotfiles-secrets"

# ── conflict-aware stow ───────────────────────────────────────────────────────

_resolve_conflicts() {
    local target="$1" use_sudo="$2" dry="$3"

    while IFS= read -r line; do
        [[ "$line" != *"existing target is neither a link nor empty: "* ]] && continue
        local rel="${line##*: }"
        local full="$target/$rel"

        printf "  conflict: %s\n  overwrite? [y/N] " "$full"
        local reply=""
        read -r reply </dev/tty || true

        if [[ "${reply,,}" == y ]]; then
            if [[ -d "$full" && ! -L "$full" ]]; then
                [[ -n "$use_sudo" ]] && sudo rm -rf "$full" || rm -rf "$full"
            else
                [[ -n "$use_sudo" ]] && sudo rm -f "$full"  || rm -f "$full"
            fi
        fi
    done <<< "$dry"
}

stow_home() {
    local dir="$1"; shift
    local dry
    dry=$(stow -d "$dir" -t "$HOME" --no --restow "$@" 2>&1) || true
    _resolve_conflicts "$HOME" "" "$dry"
    stow -d "$dir" -t "$HOME" --restow "$@"
}

stow_root() {
    local dir="$1"; shift
    local dry
    dry=$(stow -d "$dir" -t / --no --restow "$@" 2>&1) || true
    _resolve_conflicts "/" "sudo" "$dry"
    sudo stow -d "$dir" -t / --restow "$@"
}

# ── evals materialization ─────────────────────────────────────────────────────

materialize_evals() {
    find "$DOTFILES/common/claude/.claude/skills" -name "evals.json" 2>/dev/null \
    | while read -r tmpl; do
        local rel="${tmpl#$DOTFILES/common/claude/}"
        local dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"
        [[ -L "$dest" ]] && rm "$dest"
        local tmp
        tmp=$(mktemp)
        sed "s|/Users/oliversteiner|$HOME|g" "$tmpl" > "$tmp"
        mv "$tmp" "$dest"
    done
}

# ── machine profiles ──────────────────────────────────────────────────────────

install_macbook() {
    echo "→ common"
    stow_home "$DOTFILES/common" btop claude espanso ghostty git helix nvim ssh tmux yazi zsh

    echo "→ common-macos"
    stow_home "$DOTFILES/common-macos" aerospace alfred bin borders karabiner sketchybar swiftbar

    if [[ -d "$SECRETS" ]]; then
        echo "→ secrets/common"
        stow_home "$SECRETS/common"
        echo "→ secrets/common-macos"
        stow_home "$SECRETS/common-macos"
    fi

    echo "→ evals"
    materialize_evals
}

install_garfield() {
    echo "→ common"
    stow_home "$DOTFILES/common" btop git nvim ssh tmux yazi zsh

    echo "→ garfield (/etc)"
    stow_root "$DOTFILES/machines/garfield" borgmatic caddy ssh

    if [[ -d "$SECRETS" ]]; then
        echo "→ secrets/common"
        stow_home "$SECRETS/common"
        echo "→ secrets/garfield (/etc)"
        stow_root "$SECRETS/machines/garfield"
    fi
}

install_raspi() {
    echo "→ common"
    stow_home "$DOTFILES/common" btop claude git nvim ssh tmux yazi zsh

    echo "→ raspi (/etc)"
    stow_root "$DOTFILES/machines/raspi" borgmatic ssh

    if [[ -d "$SECRETS" ]]; then
        echo "→ secrets/raspi (/etc)"
        stow_root "$SECRETS/machines/raspi"
    fi

    echo "→ evals"
    materialize_evals
}

install_snoopy() {
    echo "→ common"
    stow_home "$DOTFILES/common" btop claude git nvim ssh tmux yazi zsh

    echo "→ snoopy (/etc)"
    stow_root "$DOTFILES/machines/snoopy" borgmatic ssh

    if [[ -d "$SECRETS" ]]; then
        echo "→ secrets/common"
        stow_home "$SECRETS/common"
        echo "→ secrets/snoopy (/etc)"
        stow_root "$SECRETS/machines/snoopy"
    fi

    echo "→ evals"
    materialize_evals
}

install_vm() {
    # Base packages always installed; pass extra package names as args.
    local -a base=(btop git nvim tmux yazi zsh)
    local -a pkgs=("${base[@]}" "$@")

    # Deduplicate (preserve order, no associative arrays needed)
    local -a unique=()
    local p seen=" "
    for p in "${pkgs[@]}"; do
        if [[ "$seen" != *" $p "* ]]; then
            seen+="$p "
            unique+=("$p")
        fi
    done

    echo "→ common (${unique[*]})"
    stow_home "$DOTFILES/common" "${unique[@]}"
}

# ── machine detection ─────────────────────────────────────────────────────────

detect_machine() {
    local os hn
    os=$(uname -s)
    hn=$(hostname -s 2>/dev/null || hostname)
    hn="${hn,,}"

    if   [[ "$os" == "Darwin" ]];                                    then echo "macbook"
    elif [[ "$hn" == "garfield"* ]];                                 then echo "garfield"
    elif [[ "$hn" == "raspi"* || "$hn" == "raspberrypi"* ]];        then echo "raspi"
    elif [[ "$hn" == "snoopy"* ]];                                   then echo "snoopy"
    else echo ""
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

MACHINE="${MACHINE:-$(detect_machine)}"

if [[ -z "$MACHINE" ]]; then
    echo "Could not detect machine. Set MACHINE=<name> and re-run."
    echo "Available: macbook  garfield  raspi  snoopy  vm"
    exit 1
fi

echo "machine: $MACHINE   dotfiles: $DOTFILES"

case "$MACHINE" in
    macbook)  install_macbook      ;;
    garfield) install_garfield     ;;
    raspi)    install_raspi        ;;
    snoopy)   install_snoopy       ;;
    vm)       install_vm "$@"      ;;
    *)
        echo "Unknown machine: $MACHINE"
        echo "Available: macbook  garfield  raspi  snoopy  vm"
        exit 1
        ;;
esac

echo "✓ done"
