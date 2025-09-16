# ~/.zprofile (first lines)
if [ -n "$DESKTOP_SESSION" ] || [ -n "$XDG_SESSION_DESKTOP" ]; then
  exec > >(tee -a ~/.cache/sddm-login-trace.log) 2>&1
  set -x
fi

if [ "$(uname -s)" = "Darwin" ]; then
    # macOS: Homebrew environment
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ "$(uname -s)" = "Linux" ]; then
    # Linux: start gnome-keyring for secrets (Flatpak Brave, SSH, GPG, etc.)
    if command -v gnome-keyring-daemon >/dev/null; then
        eval "$(gnome-keyring-daemon --start --components=secrets,ssh,gpg,pkcs11)"
        export SSH_AUTH_SOCK
    fi
fi

# Make Qt apps adopt GTK/portal settings (dark/light)
export QT_QPA_PLATFORMTHEME=gtk3   # Qt6: needs qt6-gtk-platformtheme; Qt5: qt5-gtk-platformtheme

export MOZ_ENABLE_WAYLAND=1
