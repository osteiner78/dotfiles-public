#!/usr/bin/env bash
line="$1"

IFS=$'\t' read -r addr _ <<< "$line"
dim=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}

/usr/local/bin/grim-hyprland -t jpeg -q 60 -w "$addr" ~/.config/hypr/scripts/alttab/preview.png
chafa --animate false -s "$dim" "$XDG_CONFIG_HOME/hypr/scripts/alttab/preview.png"
