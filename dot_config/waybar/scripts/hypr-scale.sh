#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-main}"
TARGET="${2:-}"
SIGNAL_NUM=12
DEFAULT_LAPTOP_MONITOR="${DEFAULT_LAPTOP_MONITOR:-eDP-1}"
DEFAULT_LAPTOP_SCALE="${DEFAULT_LAPTOP_SCALE:-1.33}"

get_default_scale_state_file() {
  local runtime_dir
  local session_id

  runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
  session_id="${HYPRLAND_INSTANCE_SIGNATURE:-default}"

  echo "$runtime_dir/waybar-hypr-scale-default-$session_id.state"
}

get_target_monitor_name() {
  local output_name=""

  output_name="${WAYBAR_OUTPUT_NAME:-}"
  if [[ -z "$output_name" ]]; then
    output_name="${WAYBAR_OUTPUT:-}"
  fi
  if [[ -z "$output_name" ]]; then
    output_name="${MONITOR:-}"
  fi

  echo "$output_name"
}

get_target_monitor_json() {
  local monitors
  local target_name

  monitors="$(hyprctl -j monitors 2>/dev/null || true)"
  if [[ -z "$monitors" ]]; then
  echo ""
  return
  fi

  target_name="$(get_target_monitor_name)"

  MONITORS_JSON="$monitors" TARGET_MONITOR_NAME="$target_name" python3 - <<'PY'
import json
import os
import sys

try:
  monitors = json.loads(os.environ.get("MONITORS_JSON", ""))
except Exception:
  print("")
  raise SystemExit(0)

focused = None
target_name = os.environ.get("TARGET_MONITOR_NAME", "").strip()

if target_name:
  for mon in monitors:
    if mon.get("name") == target_name:
      focused = mon
      break

for mon in monitors:
  if focused is None and mon.get("focused"):
    focused = mon
    break

if focused is None and monitors:
  focused = monitors[0]

if focused is None:
  print("")
  raise SystemExit(0)

print(json.dumps(focused, separators=(",", ":")))
PY
}

get_monitor_field() {
  local field="$1"
  local monitor_json

  monitor_json="$(get_target_monitor_json)"
  if [[ -z "$monitor_json" ]]; then
    echo ""
    return
  fi

  MONITOR_JSON="$monitor_json" python3 - "$field" <<'PY'
import json
import os
import sys

field = sys.argv[1]

try:
  monitor = json.loads(os.environ.get("MONITOR_JSON", ""))
except Exception:
    print("")
    raise SystemExit(0)

value = monitor.get(field, "")
if isinstance(value, float):
    print(f"{value:.2f}")
else:
    print(value)
PY
}

get_monitor_layout() {
  local monitor_json

  monitor_json="$(get_target_monitor_json)"
  if [[ -z "$monitor_json" ]]; then
  echo "||"
  return
  fi

  MONITOR_JSON="$monitor_json" python3 - <<'PY'
import json
import os
import sys

try:
  mon = json.loads(os.environ.get("MONITOR_JSON", ""))
except Exception:
  print("||")
  raise SystemExit(0)

name = mon.get("name", "")
width = mon.get("width")
height = mon.get("height")
refresh = mon.get("refreshRate")
x = mon.get("x")
y = mon.get("y")

if not name:
  print("||")
  raise SystemExit(0)

if width is None or height is None:
  resolution = "preferred"
else:
  if isinstance(refresh, (int, float)) and refresh > 0:
    resolution = f"{int(width)}x{int(height)}@{refresh:.2f}"
  else:
    resolution = f"{int(width)}x{int(height)}"

if x is None or y is None:
  position = "auto"
else:
  position = f"{int(x)}x{int(y)}"

print(f"{name}|{resolution}|{position}")
PY
}

normalize_scale_label() {
  local raw="$1"
  case "$raw" in
    0.75) echo "L" ;;
    1|1.0|1.00) echo "1" ;;
    1.33) echo "R" ;;
    1.5|1.50) echo "M" ;;
    *)
      if [[ "$raw" =~ ^[0-9]+\.[0-9]{2}$ ]]; then
        echo "${raw}x"
      else
        echo "${raw}x"
      fi
      ;;
  esac
}

get_current_scale() {
  local current
  current="$(get_monitor_field scale)"
  if [[ -z "$current" ]]; then
    echo "1.00"
    return
  fi
  echo "$current"
}

print_main() {
  maybe_apply_default_laptop_scale
  printf '{"text":"󰍹","class":"scale-main"}\n'
}

maybe_apply_default_laptop_scale() {
  local target_name
  local current_scale
  local should_apply
  local state_file

  target_name="$(get_target_monitor_name)"
  if [[ -z "$target_name" ]]; then
    target_name="$(get_monitor_field name)"
  fi

  if [[ "$target_name" != "$DEFAULT_LAPTOP_MONITOR" ]]; then
    return
  fi

  state_file="$(get_default_scale_state_file)"
  if [[ -f "$state_file" ]]; then
    return
  fi

  current_scale="$(get_current_scale)"
  should_apply="$(python3 - "$current_scale" "$DEFAULT_LAPTOP_SCALE" <<'PY'
import sys

try:
  current = float(sys.argv[1])
  target = float(sys.argv[2])
except Exception:
  print("0")
  raise SystemExit(0)

print("1" if abs(current - target) > 0.01 else "0")
PY
)"

  if [[ "$should_apply" == "1" ]]; then
    set_scale "$DEFAULT_LAPTOP_SCALE"
  fi

  : > "$state_file"
}

print_button() {
  local button_value="$1"
  local current
  local button_label
  local class_name=""

  current="$(get_current_scale)"
  button_label="$(normalize_scale_label "$button_value")"

  class_name="$(python3 - "$current" "$button_value" <<'PY'
import sys
cur = float(sys.argv[1])
btn = float(sys.argv[2])
print("active" if abs(cur - btn) < 0.01 else "")
PY
)"

  if [[ -n "$class_name" ]]; then
    printf '{"text":"%s","class":"%s"}\n' "$button_label" "$class_name"
  else
    printf '{"text":"%s"}\n' "$button_label"
  fi
}

reapply_hyprpaper_wallpapers() {
  local hyprpaper_conf

  hyprpaper_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprpaper.conf"
  if [[ ! -r "$hyprpaper_conf" ]]; then
    return
  fi

  python3 - "$hyprpaper_conf" <<'PY'
import re
import subprocess
import sys
import json

conf_path = sys.argv[1]

try:
  content = open(conf_path, "r", encoding="utf-8").read()
except OSError:
  raise SystemExit(0)

entries = []
for block in re.findall(r"wallpaper\s*\{(.*?)\}", content, re.S):
  monitor = ""
  path = ""
  for raw_line in block.splitlines():
    line = raw_line.split("#", 1)[0].strip()
    if not line or "=" not in line:
      continue
    key, value = [part.strip() for part in line.split("=", 1)]
    if key == "monitor":
      monitor = value
    elif key == "path":
      path = value
  if monitor and path:
    entries.append((monitor, path))

# Support line-style hyprpaper syntax as well:
# wallpaper = monitor,path
for raw_line in content.splitlines():
  line = raw_line.split("#", 1)[0].strip()
  if not line.lower().startswith("wallpaper") or "=" not in line:
    continue
  _, value = [part.strip() for part in line.split("=", 1)]
  if "," not in value:
    continue
  monitor, path = [part.strip() for part in value.split(",", 1)]
  if monitor and path:
    entries.append((monitor, path))

if not entries:
  raise SystemExit(0)

explicit = {}
for monitor, path in entries:
  if monitor not in explicit:
    explicit[monitor] = path

# Use the laptop wallpaper first when present; otherwise first configured path.
fallback_path = explicit.get("eDP-1") or next(iter(explicit.values()))

monitor_names = []
monitors_raw = subprocess.run(
  ["hyprctl", "-j", "monitors"],
  stdout=subprocess.PIPE,
  stderr=subprocess.DEVNULL,
  text=True,
  check=False,
).stdout

if monitors_raw.strip():
  try:
    monitor_data = json.loads(monitors_raw)
  except Exception:
    monitor_data = []
  for monitor in monitor_data:
    name = str(monitor.get("name", "")).strip()
    if name:
      monitor_names.append(name)

seen_paths = set()
for monitor, path in explicit.items():
  if path not in seen_paths:
    subprocess.run(
      ["hyprctl", "hyprpaper", "preload", path],
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      check=False,
    )
    seen_paths.add(path)

  subprocess.run(
    ["hyprctl", "hyprpaper", "wallpaper", f"{monitor},{path}"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
  )

for monitor in monitor_names:
  if monitor in explicit:
    continue

  if fallback_path not in seen_paths:
    subprocess.run(
      ["hyprctl", "hyprpaper", "preload", fallback_path],
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      check=False,
    )
    seen_paths.add(fallback_path)

  subprocess.run(
    ["hyprctl", "hyprpaper", "wallpaper", f"{monitor},{fallback_path}"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
  )
PY
}

set_scale() {
  local target="$1"
  local layout
  local monitor
  local resolution
  local position

  layout="$(get_monitor_layout)"
  IFS='|' read -r monitor resolution position <<< "$layout"

  if [[ -z "$monitor" ]]; then
    exit 1
  fi

  if ! hyprctl eval "hl.monitor({ output = '$monitor', mode = '$resolution', position = '$position', scale = $target })" >/dev/null 2>&1; then
    hyprctl keyword monitor "$monitor,$resolution,$position,$target" >/dev/null 2>&1 || exit 1
  fi
  reapply_hyprpaper_wallpapers
  pkill -RTMIN+"$SIGNAL_NUM" waybar >/dev/null 2>&1 || true
}

case "$MODE" in
  main)
    print_main
    ;;
  button)
    if [[ -z "$TARGET" ]]; then
      exit 1
    fi
    print_button "$TARGET"
    ;;
  set)
    if [[ -z "$TARGET" ]]; then
      exit 1
    fi
    set_scale "$TARGET"
    ;;
  *)
    exit 1
    ;;
esac
