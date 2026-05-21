# dotfiles

Personal dotfiles managed with stow.

## Structure

```
dotfiles/
├── install.sh       unified installer (auto-detects machine)
├── common/          cross-platform configs (macOS + Linux)
├── common-linux/    Linux-only configs
├── common-macos/    macOS-only configs
├── machines/        machine-specific dotfiles (borgmatic, caddy, ssh, …)
│   ├── macbook/
│   ├── garfield/    VPS
│   ├── snoopy/      Proxmox VM (media services)
│   └── raspi/       Raspberry Pi (Home Assistant + Pi-hole)
├── docker/          Docker Compose files for self-hosted services
└── archive/         retired configs
```

## Quick start

```bash
# 1. Clone both repos (dotfiles-secrets is private)
git clone git@github.com:osteiner78/dotfiles.git ~/dotfiles
git clone git@github.com:osteiner78/dotfiles-secrets.git ~/dotfiles-secrets

# 2. Run the installer — machine is auto-detected from hostname/uname
bash ~/dotfiles/install.sh

# Override machine detection if needed:
# MACHINE=garfield bash ~/dotfiles/install.sh
```

## How it works

Each application has its own Stow package — a folder that mirrors the path structure relative to `~`. Running `stow` creates symlinks in `~` pointing back into `~/dotfiles`.

```bash
# Example: install nvim config
stow -d ~/dotfiles/common -t ~ nvim

# ~/.config/nvim  →  ~/dotfiles/common/nvim/.config/nvim
```

`install.sh` does this for all packages relevant to the detected machine. If an existing non-symlinked file would conflict, the installer prompts to overwrite or skip.

## Secrets

Configs that contain secrets (API keys, tokens, private IPs) live in a separate private repo — `~/dotfiles-secrets` — which mirrors this repo's structure exactly. Both repos are stowed independently; the resulting symlinks are transparent from the application's point of view.

Never commit secrets to this repo. If a config file needs a secret, it belongs in `dotfiles-secrets`.

## Adding a new machine

1. Add an `install_<name>()` function in `install.sh` with the stow packages for that machine
2. Add a detection rule in `detect_machine()` (hostname match or uname)
3. Add a `<name>)` case in the `case "$MACHINE"` block
4. Add machine-specific dotfiles under `machines/<name>/<app>/` if needed
5. Mirror the structure in `dotfiles-secrets` if any configs contain secrets

## Adding a new application config

1. Create `common/<app>/` (or `common-linux/`, `common-macos/` if platform-specific)
2. Mirror the path structure: `common/<app>/<actual-path-from-home>/`
3. Add the package name to the relevant `install_<machine>()` call in `install.sh`
4. Test with `stow -n` (dry run) first

## Docker

The `docker/` folder contains Docker Compose files for self-hosted services. Each subfolder is a service. These are not Stow-managed — copy or reference them directly on the target host.
