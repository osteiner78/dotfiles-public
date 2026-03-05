#!/bin/bash

# --- YOUR COLORS ---
# Setprop needs colors in rrggbbaa hex format, without the "rgba(...)" part.
# Your fullscreen color from your script: "rgba(00aaaaae)" -> "00aaaaae"
FULLSCREEN_BORDER_COLOR="00aaaaae"
# --- END OF YOUR COLORS ---

# Get the address of the active window to target it specifically
ACTIVE_WINDOW_ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# Check if the active window is already fullscreen
if hyprctl activewindow -j | jq -e '.fullscreen'; then
  # IF IT IS FULLSCREEN:
  # 1. Toggle fullscreen off.
  # 2. Remove the color override for this specific window.
  #    Passing an empty value "" to setprop resets it to the global default.
  hyprctl dispatch setprop address:$ACTIVE_WINDOW_ADDRESS bordersize 2 
  sleep 0.5
  hyprctl dispatch fullscreen 1
else
  # IF IT IS NOT FULLSCREEN:
  # 1. Toggle fullscreen on.
  # 2. Apply the special border color as an override for this window only.
  hyprctl dispatch setprop address:$ACTIVE_WINDOW_ADDRESS bordersize 8
  sleep 0.5
  hyprctl dispatch fullscreen 1
  # hyprctl dispatch setprop activebordercolor "$FULLSCREEN_BORDER_COLOR" "$ACTIVE_WINDOW_ADDRESS"
fi
