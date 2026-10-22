#!/usr/bin/env python3
"""
Waybar Workspaces Pill Controller (Capsule Mode)
Handles showing the workspaces pill when the Super (Windows) key
is held for more than 2 seconds, and hiding it when released.
"""

import os
import sys
import time
import json
import signal
import subprocess
from pathlib import Path

WAYBAR_DIR = Path.home() / ".config" / "waybar"
MODE_FILE = WAYBAR_DIR / ".current_mode"
CONFIG_FILE = WAYBAR_DIR / "config.jsonc"

STATE_DIR = Path(f"/tmp/waybar_pill_{os.getuid()}")
PRESS_PID_FILE = STATE_DIR / "press.pid"
IS_SHOWN_FILE = STATE_DIR / "shown"


def init_state_dir():
    STATE_DIR.mkdir(parents=True, exist_ok=True)


def is_capsule_mode():
    if not MODE_FILE.exists():
        return False
    try:
        return MODE_FILE.read_text(encoding="utf-8").strip() == "capsule"
    except Exception:
        return False


def show_workspaces():
    if not is_capsule_mode():
        return
    try:
        data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        if isinstance(data, list):
            if len(data) > 1:
                if data[1].get("modules-center") == ["group/workspaces-pill"]:
                    return
                data[1]["modules-center"] = ["group/workspaces-pill"]
                CONFIG_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
                subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
        elif isinstance(data, dict):
            if data.get("modules-center") == ["group/workspaces-pill"]:
                return
            data["modules-center"] = ["group/workspaces-pill"]
            CONFIG_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
            subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
    except Exception:
        pass


def hide_workspaces():
    if not is_capsule_mode():
        return
    try:
        data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        if isinstance(data, list):
            if len(data) > 1:
                if data[1].get("modules-center") == []:
                    return
                data[1]["modules-center"] = []
                CONFIG_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
                subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
        elif isinstance(data, dict):
            if data.get("modules-center") == []:
                return
            data["modules-center"] = []
            CONFIG_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
            subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
    except Exception:
        pass


def on_press():
    if not is_capsule_mode():
        return
    init_state_dir()

    # If already tracking a press, kill the previous timer and restart
    if PRESS_PID_FILE.exists():
        try:
            old_pid = int(PRESS_PID_FILE.read_text().strip())
            os.kill(old_pid, signal.SIGTERM)
        except Exception:
            pass

    # Start detached background timer for 2.0s
    proc = subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "_timer"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    PRESS_PID_FILE.write_text(str(proc.pid))


def on_release():
    init_state_dir()

    # Cancel pending timer if still waiting for the 2s threshold
    if PRESS_PID_FILE.exists():
        try:
            pid = int(PRESS_PID_FILE.read_text().strip())
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass
        PRESS_PID_FILE.unlink(missing_ok=True)

    # Hide workspaces
    hide_workspaces()
    IS_SHOWN_FILE.unlink(missing_ok=True)


def on_timer():
    init_state_dir()
    time.sleep(0.5)

    # Verify that the press was not released/cancelled
    if not PRESS_PID_FILE.exists():
        return

    try:
        pid = int(PRESS_PID_FILE.read_text().strip())
        if pid != os.getpid():
            return
    except Exception:
        return

    show_workspaces()
    IS_SHOWN_FILE.write_text("1")
    PRESS_PID_FILE.unlink(missing_ok=True)


def cleanup_state():
    if PRESS_PID_FILE.exists():
        try:
            pid = int(PRESS_PID_FILE.read_text().strip())
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass
        PRESS_PID_FILE.unlink(missing_ok=True)
    IS_SHOWN_FILE.unlink(missing_ok=True)


def main():
    if len(sys.argv) < 2:
        return
    cmd = sys.argv[1]
    if cmd == "press":
        on_press()
    elif cmd == "release":
        on_release()
    elif cmd == "show":
        show_workspaces()
    elif cmd == "hide":
        hide_workspaces()
    elif cmd == "cleanup":
        cleanup_state()
    elif cmd == "_timer":
        on_timer()


if __name__ == "__main__":
    main()
