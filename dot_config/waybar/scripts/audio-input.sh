#!/bin/bash
# Pick audio input source via wofi and set it as default (excludes monitor sources)

choice=$(pactl list sources | awk '
    /Name:/        { name = $2 }
    /Description:/ { desc = substr($0, index($0, $2)); if (name !~ /\.monitor$/) print desc "|" name }
' | wofi --show dmenu --prompt "Audio Input" --width 500 --lines 8)

[ -z "$choice" ] && exit 0

source=$(echo "$choice" | cut -d'|' -f2)
pactl set-default-source "$source"
