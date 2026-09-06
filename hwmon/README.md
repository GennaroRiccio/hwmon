# HW Monitor — Omarchy panel plugin

Live CPU / MEM / NET monitor running **inside the omarchy-shell
process** — no separate Quickshell instance, no build step. A floating panel
(420 wide, 460 collapsed / 640 expanded, top-right corner) with per-metric
**pie + sparkline** and an expandable **process list**. Samples `/proc` while
visible, hidden = plugin unloaded.

<p><img src="demo/hwmon.png">
</p>

## Features

- **Pie + trend per metric** — doughnut `PieChart` (Canvas) shows current %; `Sparkline` shows the last 90 s of history (repaints only on reassignment via spread + slice).
- **CPU** — usage from a `/proc/stat` delta (two snapshots 0.15 s apart) · **MEM** — from `/proc/meminfo` · **NET** — from cumulative `/proc/net/dev` counters, loopback excluded; `netPercent` = peak ↓/↑ vs `netScale` (1024 KB/s).
- **Processi attivi** — toggle button expands an 8-row list from `ps -eo pid,comm,%cpu,%mem` (poll 2 s, only when expanded), with CPU/MEM % and a mini CPU bar.
- Self-contained palette — no dependency on Omarchy's `qs.Commons`/`qs.Ui`, all colors live in `Hwmon.qml`/`PieChart.qml`.
- Power-friendly — hidden = plugin unloaded, no timers run in background.

## Requirements

- Omarchy (omarchy-shell) with a `hyprland.lua` config — the window rule and
  keybind are applied through Omarchy's Lua bridge (`o.window`, `o.bind`).
- `jq` — used by `install.sh` to poll the shell's plugin registry.
- Hyprland, with the window rule registered (the compositor tiles the
  `FloatingWindow` by default; see [Window rules](#window-rules)).

## File layout

```
manifest.json   plugin manifest: id "gennaro.hwmon", kinds: ["panel"]
Hwmon.qml       entry point: Item root + FloatingWindow (pie + trend + process list)
PieChart.qml    doughnut Canvas (0..100 %, track + arc)
GraphRow.qml    (legacy) labelled row — kept for standalone compat
Sparkline.qml   Canvas sparkline (repaints only on series reassignment)
install.sh      install/uninstall helper that also wires up Hyprland
demo/           demo recording (hwmon.mp4 / hwmon.png)
```

## Install

```bash
./install.sh
```

This:

1. copies this folder to `~/.config/omarchy/plugins/gennaro.hwmon/` and
   validates it (`omarchy plugin validate`);
2. enables the plugin, forcing `omarchy-shell shell rescanPlugins` and polling
   `listPlugins` until the running shell knows the id (a bare `omarchy plugin
   enable` fails with "not known" while the registry still holds a pre-copy
   scan);
3. wires the Hyprland config inside `-- [hwmon-plugin]` marker blocks — the
   window rule in `hyprland.lua` and a `SUPER+F5` toggle in `bindings.lua`.

Every file the script touches is backed up to `*.bak.<timestamp>` first.
Idempotent: re-running replaces the managed blocks in place and refuses to
touch files that already carry hwmon content written by something else.

Manual equivalent:

```bash
cp -r . ~/.config/omarchy/plugins/gennaro.hwmon
omarchy plugin enable gennaro.hwmon
# if the shell doesn't pick it up: omarchy-shell shell rescanPlugins
```

## Uninstall

```bash
./install.sh uninstall
```

disables and removes the plugin (`omarchy plugin disable` / `omarchy plugin
remove --yes`), deletes the plugin folder, strips the `-- [hwmon-plugin]`
marker blocks from `hyprland.lua` and `bindings.lua`, and reloads Hyprland.
The window closes as soon as the plugin is disabled. As with install, every
touched file is backed up first.

## Toggle

```bash
omarchy-shell shell toggle gennaro.hwmon
```

or with the keybind `install.sh` sets up in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + F5", "HW Monitor", "omarchy-shell shell toggle gennaro.hwmon")
```

## Window rules

The window is a `FloatingWindow` titled `HW Monitor` (420 wide, 460 collapsed / 640 expanded). Hyprland tiles
it by default, so the rule in `~/.config/hypr/hyprland.lua` is:

```lua
o.window({ title = "^(HW Monitor)$" }, { float = true, size = { 420, 640 }, move = { "(monitor_w-window_w-20)", "(20)" } })
```

This keeps it floating at the **top-right corner** with a 20px margin (size is the max; collapsed state leaves extra paper at the bottom). `install.sh` applies this automatically.

> **Gotcha:** the `move` table form with `monitor_w`/`window_w` variables is
> required. The string form `move = "100%-w-20 20"` is silently ignored by the
> hyprland-lua bridge on current Hyprland builds — `hyprctl configerrors` stays
> clean, so a missing rule can be easy to miss.

If you change the widget's layout in `Hwmon.qml`, keep `implicitWidth` /
`implicitHeight` and the rule's `size` in sync — the size math is hand-computed
and coupled.

## Development

- `omarchy plugin validate <folder>` — schema-check a plugin folder before
  installing.
- Saving any file under `~/.config/omarchy/plugins/` auto-reloads the plugin;
  `omarchy-shell shell rescanPlugins` forces a rescan.
- Series arrays are **reassigned** via spread + slice (`Sparkline.qml` is a
  `Canvas` that repaints only on series reassignment — never push in place).