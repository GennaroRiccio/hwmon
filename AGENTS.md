# AGENTS.md

Standalone Quickshell (0.3.0, `qs` at `/usr/bin/qs`) hardware monitor widget for Hyprland — a live CPU/MEM/NET sparkline window. Not part of the Omarchy shell; no build step, no tests. The project ships both the standalone widget (root: `shell.qml`/`SysMonitor.qml`) and the publishable Omarchy plugin under `hwmon/` (id `gennaro.hwmon`, `https://github.com/GennaroRiccio/hwmon`) plus integration scripts under `scripts/`.

## Run & verify

- Launch: `qs -p ~/Work/hwmon` (from Hyprland; reloads live on save).
- Toggle via IPC: `qs ipc -p ~/Work/hwmon call hwmon toggle` — the `-p` is **required** when omarchy-shell is also running (no "default" Quickshell config exists on this machine, so instance-less `qs ipc` calls fail). Target defined in `SysMonitor.qml` `IpcHandler`; `show`/`hide` too.
- Initial visibility follows `HWMON_START_VISIBLE` (`Quickshell.env`, "0" = hidden); unset defaults to visible. `scripts/toggle.sh` starts a missing instance hidden then toggles it.
- The window is a floating `FloatingWindow` titled `HW Monitor`; Hyprland `windowrule` lines (float, `size 400 394`, top-right `move`) live in `shell.qml` as comments. On Omarchy's Lua config the rule must use `o.window`'s **table** `move` form (`{ "(monitor_w-window_w-20)", "(20)" }`) — the string form `100%-w-20 20` is silently ignored by the hyprland-lua bridge. If you change the layout/size in `SysMonitor.qml`, update that size and the implicit-size comment math (they are hand-computed and coupled). The same coupling exists in `hwmon/Hwmon.qml`.

## Omarchy integration

- `scripts/setup-omarchy.sh` — idempotent, marker-based (`-- [hwmon] ... -- [hwmon end]`) installer for Option A: autostart + SUPER+F5 keybind (→ `scripts/toggle.sh`) + window rules, with timestamped backups and `--start-hidden`. It backs up before editing and refuses to touch files that already mention hwmon outside its markers.
- `hwmon/` — the same widget as an Omarchy `panel` plugin (`gennaro.hwmon`), loaded inside omarchy-shell: root `Item` with `opened`/`open()`/`close()`, `FloatingWindow visible: root.opened`. Hidden = plugin unloaded, probe stops. Toggle: `omarchy-shell shell toggle gennaro.hwmon`. `hwmon/install.sh` copies the plugin, enables it (`omarchy plugin enable` fails with "not known" unless the shell has rescanned — the script forces `rescanPlugins` and polls `listPlugins` first), and manages its own `-- [hwmon-plugin]` marker blocks in `hyprland.lua` (window rule) + `bindings.lua` (SUPER+F5 → the toggle command). `hwmon/install.sh uninstall` reverses all of that (disable + `omarchy plugin remove`, strip the marker blocks, reload). Plugin and standalone are mutually exclusive; `hwmon/install.sh` refuses to touch config files that already carry the other variant's hwmon blocks. Plugin ids must not use the reserved `omarchy.` namespace.

## Quickshell gotchas (see also the `quickshell` skill)

- Agents lack reliable training data on Quickshell — load the `quickshell` skill before writing/reviewing these QML files.
- `Sparkline.qml` is a `Canvas` that repaints only on `onSeriesChanged`/`onColorsChanged`. Series arrays must be **reassigned**, never mutated/pushed in place. `SysMonitor.push()` (and `Hwmon.qml`'s) use spread + slice for this — keep that pattern.
- The 1 Hz `Process` probe is re-triggered by toggling `running = false; running = true` from a `Timer` that runs only while `win.visible`; it parses output via `StdioCollector`'s `onStreamFinished`.
- Data sources: CPU from a `/proc/stat` delta (two snapshots 0.15 s apart), mem from `/proc/meminfo`, net from cumulative `/proc/net/dev` counters (loopback excluded so localhost chatter doesn't count as traffic). NET values are normalized against `netScale` (KB/s).