#!/bin/bash
#/usr/local/bin/macbook-speakers.sh
# add quirks to reroute correctly sound to speakers
# Macbook Pro 2015
# cat /proc/asound/card1/codec#0 | grep Subsystem
# returns Subsystem Id: 0x106b7b00
# vs Id: 1013:4208
DEV=/dev/snd/hwC1D0

hda-verb $DEV 0x12 SET_PIN_WIDGET_CONTROL 0x40
hda-verb $DEV 0x13 SET_PIN_WIDGET_CONTROL 0x40
hda-verb $DEV 0x12 SET_EAPD_BTLENABLE 0x02
hda-verb $DEV 0x13 SET_EAPD_BTLENABLE 0x02
hda-verb $DEV 0x12 SET_AMP_GAIN_MUTE 0x00
hda-verb $DEV 0x13 SET_AMP_GAIN_MUTE 0x00

