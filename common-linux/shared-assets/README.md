# shared-assets

Not a stow package. Large assets shared by several Linux stow packages live here once;
the packages contain relative symlinks to them (stow links the symlink, which resolves
back into this folder):

- `icons/catppuccin-macchiato-dark-cursors` ← hypr-arch, hypr-asahi, niri-M1 (`.local/share/icons/`)
- `rofi-images` ← hypr-arch, niri-M1 (`.config/rofi/images`)
- `hyprlock-backgrounds` ← hypr-arch, niri-M1, niri-fedora/common (`.config/hypr/hyprlock-backgrounds`)
