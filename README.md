# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

```
dotfiles/
├── common/          cross-platform configs (macOS + Linux)
├── common-linux/    Linux-only configs
├── common-macos/    macOS-only configs
├── machines/        per-machine install scripts + machine-specific dotfiles
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

# 2. Run the install script for this machine
bash ~/dotfiles/machines/<machine-name>/install.sh
bash ~/dotfiles-secrets/machines/<machine-name>/install.sh
```

## How it works

Each application has its own Stow package — a folder that mirrors the path structure relative to `~`. Running `stow` creates symlinks in `~` pointing back into `~/dotfiles`.

```bash
# Example: install nvim config
stow -d ~/dotfiles/common -t ~ nvim

# ~/.config/nvim  →  ~/dotfiles/common/nvim/.config/nvim
```

The install scripts do this for all packages relevant to a machine.

## Secrets

Configs that contain secrets (API keys, tokens, private IPs) live in a separate private repo — `~/dotfiles-secrets` — which mirrors this repo's structure exactly. Both repos are stowed independently; the resulting symlinks are transparent from the application's point of view.

Never commit secrets to this repo. If a config file needs a secret, it belongs in `dotfiles-secrets`.

## Adding a new machine

1. Create `machines/<name>/install.sh`
2. Add machine-specific dotfiles under `machines/<name>/<app>/` if needed
3. Mirror the structure in `dotfiles-secrets` if any configs contain secrets

## Adding a new application config

1. Create `common/<app>/` (or `common-linux/`, `common-macos/` if platform-specific)
2. Mirror the path structure: `common/<app>/<actual-path-from-home>/`
3. Add `stow -d "$DOTFILES/common" -t ~ <app>` to the relevant machine install scripts
4. Test with `stow -n` (dry run) first

## Docker

The `docker/` folder contains Docker Compose files for self-hosted services. Each subfolder is a service. These are not Stow-managed — copy or reference them directly on the target host.
