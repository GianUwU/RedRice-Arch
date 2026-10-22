#!/bin/bash

state_file="$HOME/.config/waybar/.audio-max-plus"
config_file="$HOME/.config/waybar/modules.json"
audio_state_css="$HOME/.config/waybar/audio-state.css"

current=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
    | grep -oP '\d+%' | head -1 | tr -d '%')

if [ -f "$state_file" ]; then
    rm -f "$state_file"
    perl -0pi -e 's/("pulseaudio\/slider": \{\n\s+"min": 0,\n\s+"max": )200(,\n\s+"orientation": "vertical"\n\})/${1}100$2/s; s/("pulseaudio": \{\n\s+"interval": 1,\n\s+"max-volume": )200(,)/${1}100$2/s' "$config_file"
    printf '%s\n' '@define-color audio_slider_color @color8;' > "$audio_state_css"
    if [ "${current:-0}" -gt 100 ]; then
        pactl set-sink-volume @DEFAULT_SINK@ 100%
    fi
else
    : > "$state_file"
    perl -0pi -e 's/("pulseaudio\/slider": \{\n\s+"min": 0,\n\s+"max": )100(,\n\s+"orientation": "vertical"\n\})/${1}200$2/s; s/("pulseaudio": \{\n\s+"interval": 1,\n\s+"max-volume": )100(,)/${1}200$2/s' "$config_file"
    printf '%s\n' '@define-color audio_slider_color @color9;' > "$audio_state_css"
fi

pkill -SIGUSR2 waybar
