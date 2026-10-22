#!/usr/bin/env python3
import json
import subprocess
import os
import socket
import sys
import time

ICON_MAP = {
    'kitty': "<span color='#f5a97f'></span>",
    'cmdscratch': "<span color='#eed49f'></span>",
    'alacritty': "<span color='#f5a97f'></span>",
    'foot': "<span color='#f5a97f'></span>",
    'vesktop': "<span color='#8aadf4'>󰙯</span>",
    'discord': "<span color='#8aadf4'>󰙯</span>",
    'WebCord': "<span color='#8aadf4'>󰙯</span>",
    'vivaldi-stable': "<span color='#ed8796'></span>",
    'google-chrome': "<span color='#eed49f'></span>",
    'chromium': "<span color='#8bd5ca'></span>",
    'brave-browser': "<span color='#f5a97f'></span>",
    'firefox': "<span color='#f5a97f'></span>",
    'antigravity-ide': "<span color='#80c8ff'>󰨞</span>",
    'code': "<span color='#80c8ff'>󰨞</span>",
    'vscodium': "<span color='#80c8ff'>󰨞</span>",
    'org.kde.dolphin': "<span color='#91d7e3'>󰉋</span>",
    'thunar': "<span color='#91d7e3'>󰉋</span>",
    'nemo': "<span color='#91d7e3'>󰉋</span>",
    'steam': "<span color='#c6a0f6'>󰓓</span>",
    'spotify': "<span color='#a6da95'></span>",
    'obsidian': "<span color='#c6a0f6'>󱓧</span>"
}

def get_icons():
    try:
        ws_res = subprocess.run(['hyprctl', 'workspaces', '-j'], capture_output=True, text=True, timeout=1)
        workspaces = json.loads(ws_res.stdout)

        mon_res = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True, timeout=1)
        monitors = json.loads(mon_res.stdout)
        active_ws_ids = {m['activeWorkspace']['id'] for m in monitors} if monitors else {1}

        client_res = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=1)
        clients = json.loads(client_res.stdout)

        valid_ws = [w for w in workspaces if (w['windows'] > 0 or w['id'] in active_ws_ids) and w['id'] > 0]
        valid_ws.sort(key=lambda w: w['id'])

        lines = []
        for w in valid_ws:
            ws_clients = [c for c in clients if c['workspace']['id'] == w['id']]
            icons = []
            for c in ws_clients:
                cls = c.get('class', '')
                ico = ICON_MAP.get(cls, "<span color='#cad3f5'></span>")
                icons.append(ico)
            line_str = ' '.join(icons) if icons else ''
            # Use 16pt zero-width space to guarantee exact 30px row height matching workspace buttons
            lines.append(f"<span font='JetBrainsMono Nerd Font Propo 16'>&#x200B;</span><span font='JetBrainsMono Nerd Font Propo 14'>{line_str}</span>")

        output_text = '\n'.join(lines)
        return json.dumps({'text': output_text, 'tooltip': 'Workspace Applications'})
    except Exception:
        return json.dumps({'text': ''})

def main():
    # 1. Output initial state immediately
    last_output = get_icons()
    print(last_output, flush=True)

    # 2. Connect to Hyprland event socket (socket2.sock) for 0ms instantaneous updates
    his = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    xrd = os.environ.get('XDG_RUNTIME_DIR')
    if not his or not xrd:
        while True:
            time.sleep(1)
            new_output = get_icons()
            if new_output != last_output:
                print(new_output, flush=True)
                last_output = new_output

    sock_path = f"{xrd}/hypr/{his}/.socket2.sock"

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(sock_path)
                buffer = ""
                while True:
                    data = s.recv(4096).decode('utf-8', errors='ignore')
                    if not data:
                        break
                    buffer += data
                    lines = buffer.split('\n')
                    buffer = lines[-1]
                    should_update = False
                    for line in lines[:-1]:
                        if any(line.startswith(prefix) for prefix in (
                            'openwindow', 'closewindow', 'movewindow', 'workspace',
                            'createworkspace', 'destroyworkspace', 'activewindow',
                            'focusedmon', 'changefloatingmode', 'urgent', 'fullscreen'
                        )):
                            should_update = True
                            break
                    if should_update:
                        new_output = get_icons()
                        if new_output != last_output:
                            print(new_output, flush=True)
                            last_output = new_output
        except Exception:
            time.sleep(0.5)
            new_output = get_icons()
            if new_output != last_output:
                print(new_output, flush=True)
                last_output = new_output

if __name__ == '__main__':
    main()
