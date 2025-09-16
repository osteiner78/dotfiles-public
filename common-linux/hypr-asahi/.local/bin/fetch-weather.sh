#!/usr/bin/env bash
set -e
alacritty -t Weather -e bash -lc '
  curl -s "https://wttr.in/Vila_Mariana" | less -R
'  font-family: "Noto Color Emoji", "SF Pro Display", "JetBrainsMono Nerd Font Propo", sans-serif;
  line-height: 1.0;t