#!/bin/bash
# Show available WiFi networks and connect via wofi

wifi_if=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null \
    | awk -F: '$2=="wifi" && $3!="unavailable" {print $1; exit}')

[ -z "$wifi_if" ] && exit 0

networks=$(nmcli -t -f SSID,BSSID,SIGNAL,SECURITY dev wifi list ifname "$wifi_if" 2>/dev/null \
    | awk -F: '
        NF>=4 && $1!="" {
            if (!($1 in best_signal) || $3+0 > best_signal[$1]) {
                best_signal[$1] = $3+0
                best_bssid[$1] = $2
                best_security[$1] = $4
            }
        }
        END {
            for (ssid in best_signal) {
                security = best_security[ssid]
                if (security == "" || security == "--") security = "Open"
                printf "%s [%d%%] - %s\t%s\t%s\n", ssid, best_signal[ssid], security, best_bssid[ssid], ssid
            }
        }
    ' \
    | sort -t'[' -k2 -rn)

[ -z "$networks" ] && exit 0

selected=$(echo "$networks" | cut -f1 | wofi --show dmenu --prompt "WiFi Network" --width 500 --lines 12)
[ -z "$selected" ] && exit 0

selected_row=$(echo "$networks" | awk -F'\t' -v sel="$selected" '$1==sel {print; exit}')
[ -z "$selected_row" ] && exit 0

bssid=$(echo "$selected_row" | cut -f2)
ssid=$(echo "$selected_row" | cut -f3-)

if ! nmcli --wait 15 device wifi connect "$bssid" ifname "$wifi_if" 2>/dev/null; then
    password=$(echo "" | wofi --show dmenu --prompt "Password for: $ssid" --width 400 --lines 1 --password)
    [ -n "$password" ] && nmcli --wait 15 device wifi connect "$bssid" ifname "$wifi_if" password "$password"
fi
