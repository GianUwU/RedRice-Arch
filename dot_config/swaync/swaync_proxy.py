#!/usr/bin/env python3
import sys
import time
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

NODE_INFO = Gio.DBusNodeInfo.new_for_xml("""
<node>
  <interface name="org.freedesktop.Notifications">
    <method name="Notify">
      <arg type="s" name="app_name" direction="in"/>
      <arg type="u" name="replaces_id" direction="in"/>
      <arg type="s" name="app_icon" direction="in"/>
      <arg type="s" name="summary" direction="in"/>
      <arg type="s" name="body" direction="in"/>
      <arg type="as" name="actions" direction="in"/>
      <arg type="a{sv}" name="hints" direction="in"/>
      <arg type="i" name="expire_timeout" direction="in"/>
      <arg type="u" name="id" direction="out"/>
    </method>
    <method name="CloseNotification">
      <arg type="u" name="id" direction="in"/>
    </method>
    <method name="GetCapabilities">
      <arg type="as" name="capabilities" direction="out"/>
    </method>
    <method name="GetServerInformation">
      <arg type="s" name="name" direction="out"/>
      <arg type="s" name="vendor" direction="out"/>
      <arg type="s" name="version" direction="out"/>
      <arg type="s" name="spec_version" direction="out"/>
    </method>
    <signal name="NotificationClosed">
      <arg type="u" name="id"/>
      <arg type="u" name="reason"/>
    </signal>
    <signal name="ActionInvoked">
      <arg type="u" name="id"/>
      <arg type="s" name="action_key"/>
    </signal>
  </interface>
</node>
""")

INTERNAL_BUS_NAME = "org.freedesktop.NotificationsInternal"
OBJECT_PATH = "/org/freedesktop/Notifications"
INTERFACE_NAME = "org.freedesktop.Notifications"

class NotificationProxy:
    def __init__(self):
        self.bus = None
        self.active_timers = {}

    def on_bus_acquired(self, connection, name):
        self.bus = connection
        self.reg_id = connection.register_object(
            OBJECT_PATH,
            NODE_INFO.interfaces[0],
            self.handle_method_call,
            None,
            None
        )
        connection.signal_subscribe(
            INTERNAL_BUS_NAME,
            INTERFACE_NAME,
            "NotificationClosed",
            OBJECT_PATH,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_swaync_notification_closed,
            None
        )
        connection.signal_subscribe(
            INTERNAL_BUS_NAME,
            INTERFACE_NAME,
            "ActionInvoked",
            OBJECT_PATH,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_swaync_action_invoked,
            None
        )
        print("SwayNC Notification Proxy active on org.freedesktop.Notifications", flush=True)

    def on_swaync_notification_closed(self, conn, sender, path, iface, signal, params, user_data):
        noti_id, reason = params.unpack()
        self.cancel_timer(noti_id)
        conn.emit_signal(
            None,
            OBJECT_PATH,
            INTERFACE_NAME,
            "NotificationClosed",
            GLib.Variant("(uu)", (noti_id, reason))
        )

    def on_swaync_action_invoked(self, conn, sender, path, iface, signal, params, user_data):
        noti_id, action = params.unpack()
        conn.emit_signal(
            None,
            OBJECT_PATH,
            INTERFACE_NAME,
            "ActionInvoked",
            GLib.Variant("(us)", (noti_id, action))
        )

    def cancel_timer(self, noti_id):
        if noti_id in self.active_timers:
            timer_src = self.active_timers[noti_id].get("timer_src")
            if timer_src:
                GLib.source_remove(timer_src)
            del self.active_timers[noti_id]

    def handle_method_call(self, conn, sender, path, iface, method, params, invocation):
        try:
            if method == "GetCapabilities":
                res = self.bus.call_sync(
                    INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                    "GetCapabilities", None, GLib.VariantType("(as)"),
                    Gio.DBusCallFlags.NONE, -1, None
                )
                invocation.return_value(res)
            elif method == "GetServerInformation":
                res = self.bus.call_sync(
                    INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                    "GetServerInformation", None, GLib.VariantType("(ssss)"),
                    Gio.DBusCallFlags.NONE, -1, None
                )
                invocation.return_value(res)
            elif method == "CloseNotification":
                noti_id = params.unpack()[0]
                self.cancel_timer(noti_id)
                self.bus.call_sync(
                    INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                    "CloseNotification", params, None,
                    Gio.DBusCallFlags.NONE, -1, None
                )
                invocation.return_value(None)
            elif method == "Notify":
                app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout = params.unpack()

                # Check urgency
                urgency = 1
                if "urgency" in hints:
                    u_val = hints["urgency"]
                    if isinstance(u_val, GLib.Variant):
                        u_val = u_val.unpack()
                    if isinstance(u_val, int):
                        urgency = u_val

                # Determine effective timeout in ms:
                # - positive expire_timeout: use it
                # - low urgency: 3000ms
                # - critical: 0 (never expires automatically)
                # - normal default: 6000ms
                if expire_timeout > 0:
                    timeout_ms = expire_timeout
                elif expire_timeout == 0 and urgency != 2:
                    timeout_ms = 6000
                elif urgency == 0:
                    timeout_ms = 3000
                elif urgency == 2:
                    timeout_ms = 0
                else:
                    timeout_ms = 6000

                has_custom_value = "value" in hints
                if not has_custom_value and timeout_ms > 0:
                    hints["value"] = 100

                # Pack hints back into GLib.Variant
                packed_hints = {}
                for k, v in hints.items():
                    if isinstance(v, GLib.Variant):
                        packed_hints[k] = v
                    elif isinstance(v, bool):
                        packed_hints[k] = GLib.Variant("b", v)
                    elif isinstance(v, int):
                        packed_hints[k] = GLib.Variant("i", v)
                    elif isinstance(v, str):
                        packed_hints[k] = GLib.Variant("s", v)
                    elif isinstance(v, float):
                        packed_hints[k] = GLib.Variant("d", v)

                # Forward to internal swaync
                if replaces_id > 0:
                    self.cancel_timer(replaces_id)

                fwd_params = GLib.Variant("(susssasa{sv}i)", (
                    app_name,
                    replaces_id,
                    app_icon,
                    summary,
                    body,
                    actions,
                    packed_hints,
                    -1 if (timeout_ms > 0 and not has_custom_value) else expire_timeout
                ))

                res = self.bus.call_sync(
                    INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                    "Notify", fwd_params, GLib.VariantType("(u)"),
                    Gio.DBusCallFlags.NONE, -1, None
                )
                noti_id = res.unpack()[0]
                invocation.return_value(res)

                # Animate independent countdown bar if applicable
                if not has_custom_value and timeout_ms > 0:
                    self.cancel_timer(noti_id)
                    duration_sec = timeout_ms / 1000.0
                    start_time = time.time()

                    def tick():
                        if noti_id not in self.active_timers:
                            return False
                        now = time.time()
                        elapsed = now - start_time
                        remaining = max(0.0, 1.0 - (elapsed / duration_sec))
                        val = int(remaining * 100)

                        if remaining <= 0:
                            self.cancel_timer(noti_id)
                            try:
                                self.bus.call_sync(
                                    INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                                    "CloseNotification", GLib.Variant("(u)", (noti_id,)), None,
                                    Gio.DBusCallFlags.NONE, -1, None
                                )
                            except Exception:
                                pass
                            return False

                        timer_entry = self.active_timers.get(noti_id)
                        if timer_entry and timer_entry.get("last_val") == val:
                            return True

                        if timer_entry is not None:
                            timer_entry["last_val"] = val

                        timer_hints = dict(packed_hints)
                        timer_hints["value"] = GLib.Variant("i", val)

                        try:
                            update_params = GLib.Variant("(susssasa{sv}i)", (
                                app_name,
                                noti_id,
                                app_icon,
                                summary,
                                body,
                                actions,
                                timer_hints,
                                -1
                            ))
                            self.bus.call_sync(
                                INTERNAL_BUS_NAME, OBJECT_PATH, INTERFACE_NAME,
                                "Notify", update_params, GLib.VariantType("(u)"),
                                Gio.DBusCallFlags.NONE, -1, None
                            )
                        except Exception:
                            return False

                        return True

                    src_id = GLib.timeout_add(50, tick)
                    self.active_timers[noti_id] = {
                        "timer_src": src_id,
                        "start_time": start_time,
                        "duration": duration_sec,
                        "last_val": 100
                    }
        except Exception as e:
            print("Error handling method call:", e, flush=True)
            try:
                invocation.return_dbus_error("org.freedesktop.DBus.Error.Failed", str(e))
            except Exception:
                pass

def main():
    proxy = NotificationProxy()
    owner_id = Gio.bus_own_name(
        Gio.BusType.SESSION,
        "org.freedesktop.Notifications",
        Gio.BusNameOwnerFlags.REPLACE,
        proxy.on_bus_acquired,
        None,
        lambda conn, name: sys.exit(0)
    )
    GLib.MainLoop().run()

if __name__ == "__main__":
    main()
