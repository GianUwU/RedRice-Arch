#!/usr/bin/env python3
"""
Waybar Capsule Mode Toggle
Toggles between Main Mode (full bar, exclusive: true)
and Capsule Mode (clock pill only, exclusive: false for full screen estate).
"""

import sys
import json
import subprocess
from pathlib import Path

WAYBAR_DIR = Path.home() / ".config" / "waybar"
MODE_FILE = WAYBAR_DIR / ".current_mode"
CONFIG_FILE = WAYBAR_DIR / "config.jsonc"
MAIN_CONFIG = WAYBAR_DIR / "config-main.jsonc"
CAPSULE_CONFIG = WAYBAR_DIR / "config-capsule.jsonc"

PILL_HEIGHT = 100
MARGIN_TOP = 20
MARGIN_RIGHT = 3
DEFAULT_MARGIN_BOTTOM = 780


def get_monitor_logical_height():
    """Calculate logical height of focused or primary monitor."""
    try:
        res = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False
        )
        monitors = json.loads(res.stdout)
        if not monitors:
            return 900

        # Prefer focused monitor
        focused = next((m for m in monitors if m.get("focused")), monitors[0])
        h = focused.get("height", 1200)
        scale = focused.get("scale", 1.0)
        return h / scale
    except Exception:
        return 900


def get_current_mode():
    """Read active mode from state file or detect from config."""
    if MODE_FILE.exists():
        try:
            mode = MODE_FILE.read_text(encoding="utf-8").strip()
            if mode in ("main", "capsule"):
                return mode
        except Exception:
            pass

    # Inspect current config.jsonc
    if CONFIG_FILE.exists():
        try:
            content = CONFIG_FILE.read_text(encoding="utf-8")
            if '"exclusive": false' in content and '"clock"' in content:
                return "capsule"
        except Exception:
            pass

    return "main"


def activate_capsule_mode():
    if CAPSULE_CONFIG.exists():
        CONFIG_FILE.write_text(CAPSULE_CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
    else:
        capsule_data = [
            {
                "name": "capsule",
                "reload_style_on_change": True,
                "layer": "top",
                "position": "right",
                "exclusive": False,
                "margin-top": MARGIN_TOP,
                "margin-bottom": 20,
                "margin-left": 0,
                "margin-right": MARGIN_RIGHT,
                "fixed-center": True,
                "spacing": 0,
                "include": ["~/.config/waybar/modules.json"],
                "modules-left": ["group/clock-capsule"],
                "modules-center": [],
                "modules-right": []
            },
            {
                "name": "capsule",
                "reload_style_on_change": True,
                "layer": "top",
                "position": "right",
                "exclusive": False,
                "margin-top": MARGIN_TOP,
                "margin-bottom": 20,
                "margin-left": 0,
                "margin-right": MARGIN_RIGHT,
                "fixed-center": True,
                "spacing": 0,
                "include": ["~/.config/waybar/modules.json"],
                "modules-left": [],
                "modules-center": [],
                "modules-right": []
            }
        ]
        CONFIG_FILE.write_text(json.dumps(capsule_data, indent=2), encoding="utf-8")
    MODE_FILE.write_text("capsule", encoding="utf-8")

    # Cleanup workspaces pill state
    pill_script = WAYBAR_DIR / "scripts" / "workspaces-pill.py"
    if pill_script.exists():
        subprocess.run([sys.executable, str(pill_script), "cleanup"], check=False)

    # Reload Waybar
    subprocess.run(["killall", "-SIGUSR2", "waybar"], check=False)


def activate_main_mode():
    if MAIN_CONFIG.exists():
        CONFIG_FILE.write_text(MAIN_CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
    MODE_FILE.write_text("main", encoding="utf-8")

    # Cleanup workspaces pill state
    pill_script = WAYBAR_DIR / "scripts" / "workspaces-pill.py"
    if pill_script.exists():
        subprocess.run([sys.executable, str(pill_script), "cleanup"], check=False)

    # Reload Waybar
    subprocess.run(["killall", "-SIGUSR2", "waybar"], check=False)


def main():
    target = None
    if len(sys.argv) > 1:
        if sys.argv[1] in ("main", "capsule"):
            target = sys.argv[1]

    if not target:
        current = get_current_mode()
        target = "capsule" if current == "main" else "main"

    if target == "capsule":
        activate_capsule_mode()
    else:
        activate_main_mode()


if __name__ == "__main__":
    main()
