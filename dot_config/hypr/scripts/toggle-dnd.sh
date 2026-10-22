#!/usr/bin/env bash
# Toggle SwayNC Do Not Disturb (DND) and show on-screen status feedback

status="$(swaync-client -d -sw)"

if [ "$status" = "true" ]; then
    notify-send -u critical -t 1500 -a "Do Not Disturb" -i "notification-disabled" "Do Not Disturb" "Notifications Muted" -h string:x-canonical-private-synchronous:dnd-status
else
    notify-send -u critical -t 1500 -a "Do Not Disturb" -i "preferences-desktop-notification" "Do Not Disturb" "Notifications Unmuted" -h string:x-canonical-private-synchronous:dnd-status
fi
