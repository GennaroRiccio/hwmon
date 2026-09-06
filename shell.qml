import QtQuick
import Quickshell

// Standalone hardware monitor. Launch with:
//   qs -p ~/Work/hwmon
//
// Toggle visibility from a Hyprland keybind:
//   bind = SUPER, F5, exec, qs ipc -p ~/Work/hwmon call hwmon toggle
// (-p selects this instance when omarchy-shell also runs; see
// scripts/toggle.sh for a self-healing wrapper and scripts/setup-omarchy.sh
// to wire autostart + keybind + window rules into Omarchy.)
//
// The window is a normal floating window; Hyprland tiles it by default,
// so add rules to keep it at its intended size, top-right corner:
//   windowrule = float,  title:^(HW Monitor)$
//   windowrule = size 400 394, title:^(HW Monitor)$
//   windowrule = move 100%-w-20 20, title:^(HW Monitor)$
// (On Omarchy's Lua config use o.window's table form instead — see
// scripts/setup-omarchy.sh.)
ShellRoot {
    SysMonitor { }
}