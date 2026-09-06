#!/usr/bin/env bash
# Self-healing toggle for the standalone hwmon widget (Option A).
#
# Starts the hwmon Quickshell instance if it isn't running, then toggles it.
# A fresh start is hidden (HWMON_START_VISIBLE=0) so the toggle key shows it,
# matching the behaviour of an instance that was already open.
#
# Disambiguation note: Omarchy's shell runs its own Quickshell instance, so
# every qs ipc call here passes -p to select *this* config's instance.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

if ! pgrep -f "[q]s -p $ROOT" >/dev/null 2>&1; then
  HWMON_START_VISIBLE=0 nohup qs -p "$ROOT" >/dev/null 2>&1 &
  sleep 0.7
fi

qs ipc -p "$ROOT" call hwmon toggle
