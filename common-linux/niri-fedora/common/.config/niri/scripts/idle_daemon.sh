swayidle -d -w \
    timeout 60 "brightnessctl -s set 10% && brightnessctl -d kbd_backlight set 0" \
    resume "brightnessctl -r && brightnessctl -d kbd_backlight set 50%" \
    timeout 300 "qs -c noctalia-shell ipc call lockScreen lock" \
    timeout 360 "niri msg action power-off-monitors" \
    resume "niri msg action power-on-monitors" \
    before-sleep "qs -c noctalia-shell ipc call lockScreen lock"
