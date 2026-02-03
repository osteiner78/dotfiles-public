#!/bin/bash
# Changes "darkMode": true to "darkMode": false
# sed -i 's/"darkMode": true/"darkMode": false/' ~/.config/noctalia/settings.json
#
# A "safer" version for your dark-mode script
# sed -i '/"darkMode":/ s/true/false/' ~/.config/noctalia/settings.json


#!/bin/bash
case "$1" in
dark)
    sed -i '/"darkMode":/ s/false/true/' ~/.config/noctalia/settings.json
    # COLOR_SCHEME='prefer-dark'
    # GTK_THEME='Adwaita-dark'
    ;;
light)
    sed -i '/"darkMode":/ s/true/false/' ~/.config/noctalia/settings.json
    # COLOR_SCHEME='default'
    # GTK_THEME='Adwaita'
    ;;
default)
    exit 1 ;;
esac
