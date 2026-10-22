#!/bin/bash
# Pick audio output sink via wofi and set it as default

choice=$(pactl list sinks | awk '
    /Name:/        { name = $2 }
    /Description:/ { desc = substr($0, index($0, $2)); print desc "|" name }
' | wofi --show dmenu --prompt "Audio Output" --width 500 --lines 8)

[ -z "$choice" ] && exit 0

sink=$(echo "$choice" | cut -d'|' -f2)
pactl set-default-sink "$sink"
