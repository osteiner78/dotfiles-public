
if [[ "$(uname)" == "Linux" ]]; then
  export QT_QPA_PLATFORMTHEME=gtk3
  export MOZ_ENABLE_WAYLAND=1
  export XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"
fi
