# Neko Flow — Quickshell + Hyprland integration

## Hyprland

Append `hypr/keybinds.snippet.conf` to your Hyprland config (e.g. `~/.config/hypr/custom/keybinds.conf`).

Ensure `~/.local/bin` is on your `PATH` for Hyprland exec (often via `exec-once` or systemd user session).

## Quickshell (illogical-impulse / similar)

1. Copy the widget files into your Quickshell module tree:

   ```bash
   cp quickshell/FlowWidget.qml \
     ~/.config/quickshell/ii/modules/ii/background/widgets/flow/
   cp quickshell/ModeIndicator.qml \
     ~/.config/quickshell/ii/modules/common/widgets/
   ```

2. **FlowWidget** — ensure `Background.qml` includes it (you may already have this):

   ```qml
   sourceComponent: FlowWidget { ... }
   ```

3. **ModeIndicator** — add to your bar QML if desired:

   ```qml
   ModeIndicator {}
   ```

4. Reload Quickshell (e.g. Ctrl+Super+R or your restart script).

Paths used by the shipped widgets:

| Purpose | Path |
|---------|------|
| User config | `~/.config/neko-flow/` |
| Installed lib | `~/.local/share/neko-flow/lib/` |

## Sublime Text (optional)

Copy `sublime/neko_flow_prepare_doc.py` to `~/.config/sublime-text/Packages/User/`.

Super+Alt+Return uses this plugin to open mode notes in a dedicated window on Hyprland.

## Migrating from `~/.config/neko`

If you already use the legacy path:

```bash
./install.sh --config-dir "$HOME/.config/neko"
```

Or symlink config for Quickshell widgets that expect `neko-flow`:

```bash
ln -s neko ~/.config/neko-flow
```

Then install normally and keep using your existing `flow_modes.txt`.
