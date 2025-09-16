#!/usr/bin/env bash

# window identifier (matches the title you set with -t)
TITLE="Activity"

if hyprctl clients | grep -q "title: $TITLE"; then
    # If the window exists → close it
    hyprctl dispatch closewindow title:$TITLE >/dev/null
else
    # Otherwise → launch it
    hyprctl dispatch exec "alacritty -t $TITLE -e btop" >/dev/null
fi
