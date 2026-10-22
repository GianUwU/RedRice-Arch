#!/usr/bin/env python3
"""
Smooth wallpaper switcher for Hyprland using hyprpaper and gtk-layer-shell.
Performs a butter-smooth cross-fade transition between wallpapers on all monitors.
"""

import os
import sys
import json
import time
import fcntl
import subprocess
from pathlib import Path

# Paths
CONFIG_DIR = Path.home() / ".config" / "hypr"
WALLPAPER_DIR = CONFIG_DIR / "Wallpapers"
HYPRPAPER_CONF = CONFIG_DIR / "hyprpaper.conf"
LOCK_FILE = "/tmp/switch-wallpaper.lock"
WAYBAR_SIGNAL = 13  # RTMIN+13

# Supported image extensions
VALID_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


def get_wallpapers():
    """Return sorted list of available wallpaper paths."""
    if not WALLPAPER_DIR.exists():
        return []
    wallpapers = [
        f for f in sorted(WALLPAPER_DIR.iterdir())
        if f.suffix.lower() in VALID_EXTENSIONS and not f.name.startswith(".")
    ]
    return wallpapers


def get_current_wallpaper():
    """Query hyprctl hyprpaper listactive to find current wallpaper."""
    try:
        res = subprocess.run(
            ["hyprctl", "hyprpaper", "listactive"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False
        )
        for line in res.stdout.strip().splitlines():
            line = line.strip()
            if ":" in line:
                _, path = line.split(":", 1)
                p = Path(path.strip())
                if p.exists():
                    return p
    except Exception:
        pass

    # Fallback to hyprpaper.conf
    if HYPRPAPER_CONF.exists():
        try:
            with open(HYPRPAPER_CONF, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("path"):
                        parts = line.split("=", 1)
                        if len(parts) == 2:
                            p = Path(parts[1].strip())
                            if p.exists():
                                return p
        except Exception:
            pass

    wallpapers = get_wallpapers()
    return wallpapers[0] if wallpapers else None


def get_next_wallpaper(target_arg=None):
    """Determine the target wallpaper to switch to."""
    if target_arg:
        target = Path(target_arg).expanduser().resolve()
        if target.exists() and target.is_file():
            return target

    current = get_current_wallpaper()
    wp1 = WALLPAPER_DIR / "wallpaper1.png"
    wp2 = WALLPAPER_DIR / "wallpaper2.png"

    # Direct toggle between wallpaper1.png and wallpaper2.png
    if wp1.exists() and wp2.exists():
        if current and current.name == "wallpaper2.png":
            return wp1
        elif current and current.name == "wallpaper1.png":
            return wp2

    wallpapers = get_wallpapers()
    if not wallpapers:
        return None
    if len(wallpapers) == 1:
        return wallpapers[0]

    if not current:
        return wallpapers[0]

    # Find next wallpaper in list
    for idx, wp in enumerate(wallpapers):
        if wp.resolve() == current.resolve() or wp.name == current.name:
            next_idx = (idx + 1) % len(wallpapers)
            return wallpapers[next_idx]

    return wallpapers[0]


def get_monitors():
    """Get list of active monitor names from hyprctl."""
    try:
        res = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False
        )
        data = json.loads(res.stdout)
        return [m["name"] for m in data if "name" in m]
    except Exception:
        return ["eDP-1"]


def update_hyprpaper(target_path):
    """Update hyprpaper running instances and configuration file."""
    monitors = get_monitors()
    str_path = str(target_path.resolve())

    # Update active hyprpaper via IPC
    for mon in monitors:
        subprocess.run(
            ["hyprctl", "hyprpaper", "wallpaper", f"{mon},{str_path}"],
            capture_output=True,
            timeout=2,
            check=False
        )

    # Persist in hyprpaper.conf
    if HYPRPAPER_CONF.exists():
        try:
            lines = []
            with open(HYPRPAPER_CONF, "r", encoding="utf-8") as f:
                for line in f:
                    stripped = line.strip()
                    if stripped.startswith("path"):
                        lines.append(f"    path    = {str_path}\n")
                    else:
                        lines.append(line)
            with open(HYPRPAPER_CONF, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception as e:
            sys.stderr.write(f"Failed to update {HYPRPAPER_CONF}: {e}\n")

    # Signal Waybar to refresh status
    subprocess.run(["pkill", f"-RTMIN+{WAYBAR_SIGNAL}", "waybar"], check=False)


def run_transition(target_path, duration=0.45):
    """Run smooth GTK layer shell transition."""
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import Gtk, Gdk, GdkPixbuf, GtkLayerShell, GLib
    import cairo

    # Load pixbuf for the target wallpaper
    try:
        target_pixbuf = GdkPixbuf.Pixbuf.new_from_file(str(target_path.resolve()))
    except Exception as e:
        sys.stderr.write(f"Failed to load image {target_path}: {e}\n")
        update_hyprpaper(target_path)
        return

    display = Gdk.Display.get_default()
    n_monitors = display.get_n_monitors()

    windows = []
    anim_data = {
        "start_time": None,
        "duration": duration,
        "alpha": 0.0,
        "finished": False
    }

    # Easing function (smooth cubic ease-in-out)
    def ease_in_out(t):
        if t <= 0.0:
            return 0.0
        if t >= 1.0:
            return 1.0
        return t * t * (3.0 - 2.0 * t)

    def on_draw(widget, cr, pixbuf):
        alloc = widget.get_allocation()
        win_w, win_h = alloc.width, alloc.height

        # Clear background to transparent
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()

        alpha = anim_data["alpha"]
        if alpha <= 0.001:
            return False

        # Calculate cover fit
        img_w = pixbuf.get_width()
        img_h = pixbuf.get_height()
        scale = max(win_w / img_w, win_h / img_h)

        scaled_w = img_w * scale
        scaled_h = img_h * scale
        offset_x = (win_w - scaled_w) / 2.0
        offset_y = (win_h - scaled_h) / 2.0

        cr.set_operator(cairo.OPERATOR_OVER)
        cr.save()
        cr.rectangle(0, 0, win_w, win_h)
        cr.clip()
        cr.translate(offset_x, offset_y)
        cr.scale(scale, scale)
        Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
        cr.paint_with_alpha(alpha)
        cr.restore()
        return False

    def on_tick(widget, frame_clock):
        now = time.time()
        if anim_data["start_time"] is None:
            anim_data["start_time"] = now

        elapsed = now - anim_data["start_time"]
        progress = min(elapsed / anim_data["duration"], 1.0)
        anim_data["alpha"] = ease_in_out(progress)

        for win in windows:
            win.queue_draw()

        if progress >= 1.0:
            if not anim_data["finished"]:
                anim_data["finished"] = True
                # Set underlying hyprpaper while overlay is completely opaque
                update_hyprpaper(target_path)
                # Brief timeout to ensure compositor presents the hyprpaper frame
                GLib.timeout_add(60, Gtk.main_quit)
            return GLib.SOURCE_REMOVE

        return GLib.SOURCE_CONTINUE

    # Create an overlay layer window for each monitor
    for i in range(n_monitors):
        gdk_mon = display.get_monitor(i)
        win = Gtk.Window()
        win.set_title("WallpaperTransition")

        # Enable true RGBA transparency
        screen = win.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            win.set_visual(visual)
        win.set_app_paintable(True)

        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_exclusive_zone(win, -1)
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_namespace(win, "wallpaper-crossfade")
        GtkLayerShell.set_monitor(win, gdk_mon)

        area = Gtk.DrawingArea()
        area.connect("draw", on_draw, target_pixbuf)
        win.add(area)
        windows.append(win)

    # Attach frame tick callback to the first window
    if windows:
        windows[0].add_tick_callback(on_tick)

    for win in windows:
        win.show_all()

    Gtk.main()


def output_status():
    """Output JSON status for Waybar."""
    current = get_current_wallpaper()
    name = current.name if current else "None"
    target = get_next_wallpaper()
    target_name = target.name if target else "None"

    tooltip = f"Wallpaper: {name}\nLeft-click: Swap to {target_name}"
    data = {
        "text": "<span size='13pt'>󰸉</span>",
        "alt": name,
        "tooltip": tooltip,
        "class": "wallpaper"
    }
    print(json.dumps(data))


def main():
    if "--status" in sys.argv or "--json" in sys.argv:
        output_status()
        return

    # Ensure single instance
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)  # Another transition is running

    target_arg = None
    for arg in sys.argv[1:]:
        if not arg.startswith("--"):
            target_arg = arg
            break

    target = get_next_wallpaper(target_arg)
    if not target:
        sys.stderr.write("No wallpaper found.\n")
        sys.exit(1)

    run_transition(target)


if __name__ == "__main__":
    main()
