#!/usr/bin/env bash
# Omarchy integration for the standalone hwmon widget (Option A).
#
# Wires ~/Work/hwmon into Omarchy's Hyprland config:
#   1. autostart.lua   - launch the widget at login (optional --start-hidden)
#   2. bindings.lua    - SUPER+F5 toggle via scripts/toggle.sh
#   3. hyprland.lua    - float + size 420x640 + top-right window rules
#
# Idempotent and marker-based: each file gets a `-- [hwmon] ... -- [hwmon end]`
# block that is replaced in place on re-runs, so it is safe to run again after
# the project moves. Every file that is modified is first backed up to
# <file>.bak.<timestamp>. Remove the marker blocks (or restore the backups) to
# undo.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SCRIPT="$(basename "${BASH_SOURCE[0]}")"
HYPR_DIR="$HOME/.config/hypr"
START_VISIBLE=1

usage() {
  cat <<USAGE
Usage: $SCRIPT [--start-visible|--start-hidden] [-h|--help]

Options:
  --start-visible   Widget appears at login (default; matches the widget's
                    original behaviour).
  --start-hidden    Widget starts hidden; bring it up with the SUPER+F5 key.
  -h, --help        Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start-visible) START_VISIBLE=1 ;;
    --start-hidden) START_VISIBLE=0 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "$SCRIPT: unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

[[ -f "$HYPR_DIR/hyprland.lua" ]] || { echo "$SCRIPT: $HYPR_DIR/hyprland.lua not found — is Omarchy's Hyprland layout in use?" >&2; exit 1; }
[[ -f "$ROOT/shell.qml" ]] || { echo "$SCRIPT: hwmon config not found at $ROOT/shell.qml" >&2; exit 1; }
command -v qs >/dev/null || { echo "$SCRIPT: 'qs' (Quickshell) not found on PATH" >&2; exit 1; }

BEGIN="-- [hwmon] managed by $ROOT/scripts/$SCRIPT"
END="-- [hwmon end]"

# replace_block <file> <block-lines...>
#   Appends <block> to <file> wrapped in begin/end markers, or replaces an
#   existing block in place. Skips (with a warning) if hwmon lines already
#   exist without our markers. Backs the file up before any write.
replace_block() {
  local file="$1"; shift
  local has_block=0 has_other=0

  if grep -qF -e "$BEGIN" "$file" && grep -qF -e "$END" "$file"; then has_block=1; fi
  if (( !has_block )) && grep -qEi 'hwmon|HW Monitor' "$file"; then has_other=1; fi

  if (( has_other )); then
    echo "! $file already mentions hwmon outside a managed block — skipping (edit it by hand)." >&2
    return 0
  fi

  if (( has_block )); then
    echo "= $file: replacing existing managed block"
  else
    echo "= $file: adding managed block"
  fi

  local backup="$file.bak.$(date +%s)"
  cp -a "$file" "$backup"
  echo "  backed up $file -> $backup"

  local tmp="$file.tmp.$$"
  if (( has_block )); then
    # Whole-line comparison so paths/slashes in the markers need no escaping.
    awk -v b="$BEGIN" -v e="$END" '
      $0 == b { skip = 1 }
      !skip { print }
      $0 == e { skip = 0 }
    ' "$file" >"$tmp"
  else
    cp -a "$file" "$tmp"
  fi

  # Drop trailing blank lines so re-runs don't accumulate empty rows.
  sed -i -e :a -e '/^\n*$/{$d;N;ba;}' "$tmp"

  {
    if [[ -s $tmp ]]; then
      tail -c1 "$tmp" | grep -q $'\n' || printf '\n'
    fi
    printf '%s\n' "$BEGIN"
    printf '%s\n' "$@"
    printf '%s\n' "$END"
    printf '\n'
  } >>"$tmp"
  mv "$tmp" "$file"
  echo "+ $file: updated"
}

echo "hwmon project: $ROOT"

# --- 1. autostart ------------------------------------------------------------
if (( START_VISIBLE )); then
  start_cmd='o.launch_on_start("qs -p '"$ROOT"'")'
else
  start_cmd='o.launch_on_start("env HWMON_START_VISIBLE=0 qs -p '"$ROOT"'")'
fi
replace_block "$HYPR_DIR/autostart.lua" "$start_cmd"

# --- 2. keybind --------------------------------------------------------------
replace_block "$HYPR_DIR/bindings.lua" \
  'o.bind("SUPER + F5", "HW Monitor", "'"$ROOT"'/scripts/toggle.sh")'

# --- 3. window rules ---------------------------------------------------------
replace_block "$HYPR_DIR/hyprland.lua" \
  'o.window({ title = "^(HW Monitor)$" }, { float = true, size = { 420, 640 }, move = { "(monitor_w-window_w-20)", "(20)" } })'

# --- validate ----------------------------------------------------------------
echo "== reloading Hyprland config"
hyprctl reload >/dev/null 2>&1 || { echo "! hyprctl reload failed" >&2; exit 1; }
sleep 0.3
if errors=$(hyprctl configerrors); then
  echo "$errors"
else
  echo "! could not read hyprctl configerrors" >&2
fi

echo "== done. Toggle the widget with SUPER+F5 (or: $ROOT/scripts/toggle.sh)."
echo "   To undo, remove the '-- [hwmon]' blocks or restore the .bak backups."
