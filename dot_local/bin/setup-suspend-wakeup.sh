#!/bin/bash
set -euo pipefail

RULE_FILE="/etc/udev/rules.d/90-disable-mouse-wakeup.rules"

echo "Configuring udev rules to prevent mouse and touchpad from waking the system..."

cat << 'RULES' > "$RULE_FILE"
# Disable wakeup for Logitech Bolt Receiver (USB ID 046d:c548)
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c548", ATTR{power/wakeup}="disabled"

# Disable wakeup for Logitech Unifying Receiver (USB ID 046d:c52b)
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b", ATTR{power/wakeup}="disabled"

# Disable wakeup for ASUS built-in Touchpad (I2C ASUE140D)
ACTION=="add|change", SUBSYSTEM=="i2c", ATTR{name}=="ASUE140D:00", ATTR{power/wakeup}="disabled"
RULES

echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# Apply immediately to currently active sysfs paths
if [ -f /sys/bus/i2c/devices/i2c-ASUE140D:00/power/wakeup ]; then
    echo "Disabling touchpad wakeup immediately..."
    echo disabled > /sys/bus/i2c/devices/i2c-ASUE140D:00/power/wakeup
fi

for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ] && [ -f "$dev/power/wakeup" ]; then
        v=$(cat "$dev/idVendor" 2>/dev/null || true)
        p=$(cat "$dev/idProduct" 2>/dev/null || true)
        if [ "$v" = "046d" ] && { [ "$p" = "c548" ] || [ "$p" = "c52b" ]; }; then
            echo "Disabling Logitech receiver ($v:$p at $(basename "$dev")) wakeup immediately..."
            echo disabled > "$dev/power/wakeup"
        fi
    fi
done

echo ""
echo "=== Current Wakeup Configuration ==="
echo -n "Built-in Laptop Keyboard (serio0): "
cat /sys/devices/platform/i8042/serio0/power/wakeup 2>/dev/null || echo "not found"

echo -n "Built-in Touchpad (ASUE140D:00):    "
cat /sys/bus/i2c/devices/i2c-ASUE140D:00/power/wakeup 2>/dev/null || echo "not found"

for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ] && [ -f "$dev/power/wakeup" ]; then
        v=$(cat "$dev/idVendor" 2>/dev/null || true)
        p=$(cat "$dev/idProduct" 2>/dev/null || true)
        if [ "$v" = "046d" ]; then
            echo -n "Logitech Receiver ($v:$p):       "
            cat "$dev/power/wakeup"
        fi
    fi
done
echo "====================================="
echo "Done! The system will now only wake up from keyboard / power button / lid."
