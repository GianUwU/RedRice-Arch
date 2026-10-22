# hypr-zstack

A custom Hyprland C++ plugin implementing **stack-based visual workspace switching along the Z-axis**.

## Features

1. **Z-Axis Workspace Stacking**: Workspaces remain visually stacked along the Z-axis, allowing background workspaces to show through transparent windows and empty workspace space.
2. **Slide-In on Forward Switch**: Switching to a new workspace slides the new workspace in on top of the current one, keeping previous workspaces visible underneath.
3. **Slide-Away on Switch-Back**: Switching back to an existing workspace in the stack slides the current top workspace away (revealing the background workspace beneath).
4. **3-Workspace Stack Limit**: Limits the visible background stack to a maximum of 3 workspaces. When a new workspace is added on top, the oldest workspace at the bottom slides out of view.
5. **Strict Input Isolation**: Background workspaces in the stack are strictly non-interactable (hooks `CViewHitTester::windowAt`). You can only click, focus, or drag windows on the active workspace; background workspaces purely display as live background visuals.
6. **Transparent Stacking Blurs**: Full support for transparent tiled / floating / fullscreen windows layering seamlessly over stacked workspaces without X-ray wallpaper culling.

## Building

```bash
cd ~/.config/hypr/plugins/hypr-zstack
make
```

## Loading

To load manually:
```bash
hyprctl plugin load ~/.config/hypr/plugins/hypr-zstack/hypr-zstack.so
```

To unload:
```bash
hyprctl plugin unload ~/.config/hypr/plugins/hypr-zstack/hypr-zstack.so
```

Loaded automatically on Hyprland startup in `~/.config/hypr/hyprland.lua`.
