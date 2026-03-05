#!/bin/bash
case "$1" in
dark)
    sed -i '/"darkMode":/ s/false/true/' ~/.config/noctalia/settings.json
    ;;
light)
    sed -i '/"darkMode":/ s/true/false/' ~/.config/noctalia/settings.json
    ;;
default)
    exit 1 ;;
esac
