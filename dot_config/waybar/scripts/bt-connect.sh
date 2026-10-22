#!/bin/bash
# Show paired bluetooth devices and connect via wofi

devices=$(bluetoothctl devices Paired 2>/dev/null | sed 's/^Device //')
[ -z "$devices" ] && exit 0

selected=$(echo "$devices" | wofi --show dmenu --prompt "Connect to Device" --width 400 --lines 8)
[ -z "$selected" ] && exit 0

mac=$(echo "$selected" | awk '{print $1}')
bluetoothctl connect "$mac"
