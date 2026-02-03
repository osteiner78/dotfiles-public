#!/bin/bash
case "$1" in
dark)
    COLOR_SCHEME='prefer-dark'
    GTK_THEME='Adwaita-dark'
    ;;
light)
    COLOR_SCHEME='default'
    GTK_THEME='Adwaita'
    ;;
default)
    exit 1 ;;
esac

gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME"
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"

