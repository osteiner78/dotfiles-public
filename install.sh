#!/usr/bin/env bash
# Dotfiles installer — stows configs for the current machine using GNU Stow.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
SECRETS="$HOME/dotfiles-secrets"

# ── help ──────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: [MACHINE=<name>] ./install.sh [-h] [extra-packages...]

Stows dotfiles for the current machine. The machine is auto-detected from
hostname/uname; use MACHINE=<name> to override.

MACHINES
  macbook   macOS (arm64) — full desktop setup
              common:       btop claude espanso ghostty git nvim ssh tmux yazi zsh
              common-macos: bin borders karabiner swiftbar
              secrets:      common + common-macos (if ~/dotfiles-secrets exists)

  garfield  Linux VPS — home server running Docker
              common:  btop git nvim ssh tmux yazi zsh
              etc:     borgmatic caddy ssh  (sudo stow → /)
              secrets: common + garfield/etc

  raspi     Raspberry Pi — Home Assistant + Pi-hole
              common:  btop claude git nvim ssh tmux yazi zsh
              etc:     borgmatic ssh  (sudo stow → /)
              secrets: raspi/etc

  snoopy    Proxmox VM — media services
              common:  btop claude git nvim ssh tmux yazi zsh
              etc:     borgmatic ssh  (sudo stow → /)
              secrets: common + snoopy/etc

  vm        Temporary/disposable VM — no secrets, no root stow
              base:    btop git nvim tmux yazi zsh
              extras:  any additional packages from common/ passed as args

EXAMPLES
  ./install.sh                          # auto-detect machine, install all
  MACHINE=vm ./install.sh               # minimal base on a temp VM
  MACHINE=vm ./install.sh claude helix  # minimal base + extras
  MACHINE=garfield ./install.sh         # force garfield profile

CONFLICTS
  If a non-symlinked file already exists at a stow target path, the installer
  pauses and asks whether to overwrite it. Answering 'n' skips the prompt but
  stow will still abort that package — resolve manually if needed.

ENVIRONMENT
  MACHINE   Override auto-detected machine name
  DOTFILES  Path to this repo (default: ~/dotfiles)
EOF
}

for arg in "$@"; do
    [[ "$arg" == "-h" || "$arg" == "--help" ]] && {
        usage
        exit 0
    }
done

# ── conflict-aware stow ───────────────────────────────────────────────────────

_resolve_conflicts() {
    local target="$1" use_sudo="$2" dry="$3"
    local rel full

    while IFS= read -r line; do
        # Older stow: "* existing target is neither a link nor empty: <path>"
        if [[ "$line" == *"existing target is neither a link nor empty: "* ]]; then
            rel="${line##*: }"

        # Newer stow (Homebrew): "* cannot stow <src> over existing target <dest> since..."
        elif [[ "$line" =~ "over existing target "(.*)" since neither" ]]; then
            rel="${BASH_REMATCH[1]}"

        # Source-side absolute symlink — can't fix by removing a target; warn and skip.
        # The symlink in the dotfiles repo itself needs to be fixed (remove or make relative).
        elif [[ "$line" == *"source is an absolute symlink"* ]]; then
            echo "  warning: broken absolute symlink in source — skipping (fix the repo, not the target)"
            echo "  $line"
            continue

        else
            continue
        fi

        full="$target/$rel"
        printf "  conflict: %s\n  overwrite? [y/N] " "$full"
        local reply=""
        read -r reply </dev/tty || true

        if [[ "${reply,,}" == y ]]; then
            if [[ -d "$full" && ! -L "$full" ]]; then
                [[ -n "$use_sudo" ]] && sudo rm -rf "$full" || rm -rf "$full"
            else
                [[ -n "$use_sudo" ]] && sudo rm -f "$full" || rm -f "$full"
            fi
        fi
    done <<<"$dry"
}

_stow_pkg() {
    local dir="$1" target="$2" use_sudo="$3" pkg="$4"

    local stow_flags=(--ignore='\.DS_Store')

    local dry
    dry=$(stow -d "$dir" -t "$target" --no --restow "${stow_flags[@]}" "$pkg" 2>&1) || true
    _resolve_conflicts "$target" "$use_sudo" "$dry"

    local ok=true
    if [[ -n "$use_sudo" ]]; then
        sudo stow -d "$dir" -t "$target" --restow "${stow_flags[@]}" "$pkg" 2>/dev/null || ok=false
    else
        stow -d "$dir" -t "$target" --restow "${stow_flags[@]}" "$pkg" 2>/dev/null || ok=false
    fi

    [[ "$ok" == false ]] && echo "  ! $pkg: skipped (unresolved conflicts)"
    return 0
}

stow_home() {
    local dir="$1"
    shift
    for pkg in "$@"; do _stow_pkg "$dir" "$HOME" "" "$pkg"; done
}

stow_root() {
    local dir="$1"
    shift
    for pkg in "$@"; do _stow_pkg "$dir" "/" "sudo" "$pkg"; done
}

# ── evals materialization ─────────────────────────────────────────────────────
# evals.json files contain absolute paths and can't be stowed directly.
# They are copied from the repo template with $HOME substituted.

materialize_evals() {
    find "$DOTFILES/common/claude/.claude/skills" -name "evals.json" 2>/dev/null |
        while read -r tmpl; do
            local rel="${tmpl#$DOTFILES/common/claude/}"
            local dest="$HOME/$rel"
            mkdir -p "$(dirname "$dest")"
            [[ -L "$dest" ]] && rm "$dest"
            local tmp
            tmp=$(mktemp)
            sed "s|/Users/oliversteiner|$HOME|g" "$tmpl" >"$tmp"
            mv "$tmp" "$dest"
        done
}

# ── machine profiles ──────────────────────────────────────────────────────────

install_macbook() {
    echo "→ common"
    stow_home "$DOTFILES/common" btop claude espanso ghostty git nvim ssh tmux yazi zsh

    echo "→ common-macos"
    stow_home "$DOTFILES/common-macos" bin borders karabiner swiftbar

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
    # Baseline packages; any positional args are added on top and deduplicated.
    local -a base=(btop git nvim tmux yazi zsh)
    local -a pkgs=("${base[@]}" "$@")

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

    if [[ "$os" == "Darwin" ]]; then
        echo "macbook"
    elif [[ "$hn" == "garfield"* ]]; then
        echo "garfield"
    elif [[ "$hn" == "raspi"* || "$hn" == "raspberrypi"* ]]; then
        echo "raspi"
    elif [[ "$hn" == "snoopy"* ]]; then
        echo "snoopy"
    else
        echo ""
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

MACHINE="${MACHINE:-$(detect_machine)}"

if [[ -z "$MACHINE" ]]; then
    echo "error: could not detect machine. Set MACHINE=<name> and re-run."
    echo "Run './install.sh --help' for available machines."
    exit 1
fi

echo "machine: $MACHINE   dotfiles: $DOTFILES"

case "$MACHINE" in
macbook) install_macbook ;;
garfield) install_garfield ;;
raspi) install_raspi ;;
snoopy) install_snoopy ;;
vm) install_vm "$@" ;;
*)
    echo "error: unknown machine '$MACHINE'"
    echo "Run './install.sh --help' for available machines."
    exit 1
    ;;
esac

echo "✓ done"
