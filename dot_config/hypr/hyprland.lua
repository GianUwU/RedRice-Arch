-- Hyprland Lua Configuration
-- Refer to https://wiki.hypr.land/Configuring/ for more information

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.33,
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty -1"
local fileManager = "dolphin"
local menu        = "wofi --show drun"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("kitty -1 --start-as=hidden")
    hl.exec_cmd("rclone mount GoogleDrive: ~/drive/")
    hl.exec_cmd("hyprctl plugin load ~/.config/hypr/plugins/hypr-zstack/hypr-zstack.so")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Adwaita")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- See https://wiki.hypr.land/Configuring/Variables/
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,
        border_size = 2,
        col = {
            active_border = { colors = {"rgba(117,5,0,1)", "rgba(0,0,0,1)"}, angle = 45 },
            inactive_border = "rgba(0,0,0,1)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 35,
        rounding_power = 1,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        dim_special = 0.1,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 2,
            passes = 3,
            noise = 0.07,
            vibrancy = 0.2,
            brightness = 1.2,
            ignore_opacity = true,
            new_optimizations = false,
            xray = false,
        },
    },

    misc = {
        enable_swallow = true,
        swallow_regex = "^(kitty)$",
        disable_splash_rendering = true,
        disable_hyprland_logo = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        render_unfocused_fps = 60,
        col = {
            splash = 0x00000000,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

--------------------
---- ANIMATIONS ----
--------------------

-- See https://wiki.hypr.land/Configuring/Animations/
hl.config({
    animations = {
        enabled = true,
    },
})

-- Curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("easeOutCubic",   { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("snappy",         { type = "bezier", points = { {0.2, 0.9}, {0.1, 1.0} } })
hl.curve("pop",            { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

-- Animation Trees (speed is in deciseconds: 1 = 100ms)
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
hl.animation({ leaf = "global",        enabled = true,  speed = 10,  bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 3.5, bezier = "easeOutCubic" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 3,   bezier = "snappy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.2, bezier = "pop",          style = "popin 20%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2.5, bezier = "snappy",       style = "popin 20%" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 2.6, bezier = "snappy" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.8, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 2.2, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 2.8, bezier = "snappy" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 2.8, bezier = "snappy",       style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2,   bezier = "snappy",       style = "slide" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.8, bezier = "almostLinear" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 6,   bezier = "quick" })

-- Workspaces animation
hl.animation({ leaf = "workspaces",    enabled = false })
hl.animation({ leaf = "workspacesIn",  enabled = false })
hl.animation({ leaf = "workspacesOut", enabled = false })

-----------------
---- LAYOUTS ----
-----------------

hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "ch",
        kb_variant = "de",
        follow_mouse = 1,
        sensitivity = 0.2,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.2,
        },
    },
})

-- Gestures (v0.51+)
hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = "workspace",
})

-- Per-device config
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Applications & Windows
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("vivaldi --new-window"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("vesktop"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("antigravity-ide"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("steam"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("onlyoffice"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("vivaldi teams.microsoft.com"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("vivaldi onenote.cloud.microsoft"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprshot -m region -o ~/Documents/Screenshots"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + section", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + code:49", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + G", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Notifications (SwayNC)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-dnd.sh"))

-- Move Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-9
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. i, hl.dsp.exec_raw("zstack:remove " .. i))
end
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_raw("zstack:clear"))

-- Special Workspaces (Scratchpads)
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + Tab", hl.dsp.workspace.toggle_special("cmd"))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "special:magic" }))

-- Workspace Scrolling
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Right-click empty desktop launcher
hl.bind("mouse:273", hl.dsp.exec_cmd("bash -c 'hyprctl activewindow | grep -q \"No active window\" && wofi --show drun'"), { non_consuming = true })

-- Mouse Drag & Resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop Multimedia & Brightness Keys
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),       { locked = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),      { locked = true })
hl.bind("XF86AudioMicMute",       hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),    { locked = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true })

-- Media Control Keys
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Waybar Pill Mode: show workspaces pill on holding Super for > 2s
local super_tracking = false

local function track_super_key()
    if super_tracking then return end
    super_tracking = true

    local ticks = 0
    local pill_shown = false

    local check_timer
    check_timer = function()
        local is_down = hl.is_key_down("Super_L") or hl.is_key_down("Super_R")

        if is_down then
            ticks = ticks + 1
            if ticks >= 10 and not pill_shown then
                pill_shown = true
                hl.exec_cmd("python3 ~/.config/waybar/scripts/workspaces-pill.py show")
            end
            hl.timer(check_timer, { timeout = 50, type = "oneshot" })
        else
            super_tracking = false
            if pill_shown then
                hl.exec_cmd("python3 ~/.config/waybar/scripts/workspaces-pill.py hide")
            end
        end
    end

    hl.timer(check_timer, { timeout = 50, type = "oneshot" })
end

hl.bind("Super_L", track_super_key, { non_consuming = true })
hl.bind("Super_R", track_super_key, { non_consuming = true })

----------------------------------
---- WORKSPACE & WINDOW RULES ----
----------------------------------


hl.window_rule({
    name = "pip_auto_float",
    match = {
        title = "(?i)^Picture[- ]in[- ]Picture$",
    },
    float = true,
    pin = true,
    min_size = "640 360",
})

-- Special cmd scratchpad on-created rule
hl.workspace_rule({
    workspace = "special:cmd",
    on_created_empty = "[workspace special:cmd silent; float; size 900 520; move 20 (monitor_h-540)] kitty --class cmdscratch",
})

-- Antigravity IDE Transparency
hl.window_rule({
    name = "antigravity_opacity",
    match = {
        class = "^antigravity-ide$",
    },
    opacity = "0.92 0.85",
})

-- Obsidian Transparency & Compositor Blur
hl.window_rule({
    name = "obsidian_opacity",
    match = {
        class = "^([oO]bsidian|md\\.obsidian\\.Obsidian)$",
    },
    opacity = "0.99 override 0.99 override",
})

-- Dolphin Floating & Transparency
hl.window_rule({
    name = "dolphin_float",
    match = {
        class = "^org.kde.dolphin$",
    },
    float = true,
})

hl.window_rule({
    name = "dolphin_opacity",
    match = {
        class = "^org.kde.dolphin$",
    },
    opacity = "0.99 override 0.99 override",
})

-- Cmdscratch Scratchpad Rules
hl.window_rule({
    name = "cmdscratch_workspace",
    match = {
        class = "^cmdscratch$",
    },
    workspace = "special:cmd silent",
})

hl.window_rule({
    name = "cmdscratch_float",
    match = {
        class = "^cmdscratch$",
    },
    float = true,
})

hl.window_rule({
    name = "cmdscratch_size",
    match = {
        class = "^cmdscratch$",
    },
    size = "900 520",
})

hl.window_rule({
    name = "cmdscratch_move",
    match = {
        class = "^cmdscratch$",
    },
    move = "20 (monitor_h-540)",
})

-- Kitty Touchpad Scroll Factor & X-ray Rules
hl.window_rule({
    name = "kitty_scroll",
    match = {
        class = "^kitty$",
    },
    scroll_touchpad = 2,
    xray = false,
})

-- Suppress maximize events so apps don't maximize over existing tiled windows
hl.window_rule({
    name = "suppress_maximize",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

-- Wofi Blur & Stability Layer Rule
-- Note: ignorezero and ignorealpha are set in hyprland.conf (conf-only syntax)
hl.layer_rule({
    name = "wofi_blur",
    match = {
        namespace = "^wofi$",
    },
    blur = true,
    animation = "slide left",
})

hl.layer_rule({
    name = "waybar_anim",
    match = {
        namespace = "^waybar$",
    },
    animation = "slide right",
})

hl.layer_rule({
    name = "capsule_noanim",
    match = {
        namespace = "^capsule$",
    },
    no_anim = true,
})

hl.layer_rule({
    name = "selection_noanim",
    match = {
        namespace = "^selection$",
    },
    no_anim = true,
})

hl.layer_rule({
    name = "hyprpicker_noanim",
    match = {
        namespace = "^hyprpicker$",
    },
    no_anim = true,
})

hl.layer_rule({
    name = "swaync_blur",
    match = {
        namespace = "^swaync-notification-window$",
    },
    blur = true,
})

hl.layer_rule({
    name = "swaync_cc_blur",
    match = {
        namespace = "^swaync-control-center$",
    },
    blur = true,
})


