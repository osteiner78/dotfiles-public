

# Make Qt apps adopt GTK/portal settings (dark/light)
export QT_QPA_PLATFORMTHEME=gtk3   # Qt6: needs qt6-gtk-platformtheme; Qt5: qt5-gtk-platformtheme

export MOZ_ENABLE_WAYLAND=1

export XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"
