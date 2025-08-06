#!/bin/bash

# Set session-specific environment variables
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# This is the crucial part:
# It tells the systemd user instance and D-Bus about the graphical session,
# allowing services (like Polkit) to find their way back to your screen.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# Launch Hyprland
exec Hyprland
