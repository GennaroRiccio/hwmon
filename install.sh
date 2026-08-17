#!/usr/bin/env bash
# Install or uninstall the hwmon panel plugin for Omarchy.
#
#   install.sh               install: copy this folder to
#                            ~/.config/omarchy/plugins/gennaro.hwmon/, enable
#                            it (rescan + poll), add a Hyprland window rule
#                            (float, 400x394, top-right corner) and a SUPER+F5
#                            keybind toggling the plugin.
#   install.sh uninstall     uninstall: disable + remove the plugin and strip
#                            the "-- [hwmon-plugin]" blocks from the Hyprland
#                            config again.
#
# Idempotent, marker-based (`-- [hwmon-plugin] ... -- [hwmon-plugin end]`),
# backs up every file it touches. The Hyprland edits are skipped (with a
# warning) if a file already carries hwmon blocks written by something else,
# e.g. scripts/setup-omarchy.sh (the standalone variant — don't run both).

set -euo pipefail

ID="gennaro.hwmon"
TOGGLE_CMD="omarchy-shell shell toggle $ID"
SRC="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
DEST="$PLUGINS_DIR/$ID"
HYPR_DIR="$HOME/.config/hypr"

FILES=(manifest.json Hwmon.qml GraphRow.qml Sparkline.qml)

BEGIN="-- [hwmon-plugin] managed by install.sh"
END="-- [hwmon-plugin end]"

MODE="${1:-install}"
case "$MODE" in
  install) : ;;
  uninstall|remove) : ;;
  *) echo "usage: $0 [uninstall]" >&2; exit 2 ;;
esac

for f in "${FILES[@]}"; do
  [[ -f "$SRC/$f" ]] || { echo "install.sh: missing $SRC/$f" >&2; exit 1; }
done

mkdir -p "$PLUGINS_DIR"

# -------------------------------------------------------------- shared helpers
# (defined before use by both install and uninstall branches)

# backup_file <file> — timestamped backup; no-op when not writeable/relevant.
backup_file() {
  local file="$1"
  local backup="$file.bak.$(date +%s)"
  cp -a "$file" "$backup"
  echo "  backed up $file -> $backup"
}

# replace_block <file> <block-lines...>
#   Appends <block> to <file> wrapped in begin/end markers, or replaces an
#   existing install.sh block in place. Skips (with a warning) if the file
#   carries other hwmon content (e.g. the standalone variant's setup-omarchy.sh
#   blocks). Backs the file up before any write.
replace_block() {
  local file="$1"; shift
  local has_block=0 has_other=0

  if grep -qF -e "$BEGIN" "$file" && grep -qF -e "$END" "$file"; then has_block=1; fi
  if (( !has_block )) && grep -qEi 'hwmon|HW Monitor' "$file"; then has_other=1; fi

  if (( has_other )); then
    echo "! $file already mentions hwmon outside an install.sh block — skipping (edit it by hand)." >&2
    return 0
  fi

  if (( has_block )); then
    echo "= $file: replacing existing managed block"
  else
    echo "= $file: adding managed block"
  fi

  backup_file "$file"

  local tmp="$file.tmp.$$"
  if (( has_block )); then
    awk -v b="$BEGIN" -v e="$END" '
      $0 == b { skip = 1 }
      !skip { print }
      $0 == e { skip = 0 }
    ' "$file" >"$tmp"
  else
    cp -a "$file" "$tmp"
  fi
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

# remove_block <file> — strips the install.sh marker block (if present) in
# place, with a backup. No-op for files without it or missing files.
remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if ! grep -qF -e "$BEGIN" -e "$END" "$file"; then
    echo "= $file: no managed block to remove"
    return 0
  fi

  echo "= $file: removing managed block"
  backup_file "$file"

  local tmp="$file.tmp.$$"
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1 }
    !skip { print }
    $0 == e { skip = 0 }
  ' "$file" >"$tmp"
  sed -i -e :a -e '/^\n*$/{$d;N;ba;}' "$tmp"
  mv "$tmp" "$file"
  echo "+ $file: updated"
}

# ------------------------------------------------------------------ uninstall
if [[ "$MODE" == uninstall ]]; then

  echo "== disabling plugin $ID"
  omarchy plugin disable "$ID" 2>/dev/null \
    || echo "  (was not enabled, or no running shell — nothing to disable)"
  omarchy plugin remove "$ID" --yes 2>/dev/null || true
  rm -rf "$DEST"
  echo "= removed $DEST"

  remove_block "$HYPR_DIR/hyprland.lua"
  remove_block "$HYPR_DIR/bindings.lua"

  echo "== reloading Hyprland config"
  hyprctl reload >/dev/null 2>&1 \
    || echo "! hyprctl reload failed — config edits are on disk but not live" >&2

  echo "== uninstalled. Plugin removed; SUPER+F5 and the window rule stripped."
  exit 0
fi

# ---------------------------------------------------------------- install: copy

rm -rf "$DEST"
mkdir -p "$DEST"
for f in "${FILES[@]}"; do
  cp -a "$SRC/$f" "$DEST/$f"
done

omarchy plugin validate "$DEST"

# `omarchy plugin enable` asks the *running* shell (omarchy-shell shell
# enablePlugin) and fails with "not known" while its plugin registry still
# holds a pre-copy scan. Force a rescan, then wait until the plugin is visible
# before enabling it.
omarchy-shell -q shell rescanPlugins || true
for _ in $(seq 1 30); do
  if timeout 5 omarchy-shell shell listPlugins 2>/dev/null \
      | jq -e --arg id "$ID" 'any(.[]; .id == $id)' >/dev/null 2>&1; then
    found=1
    break
  fi
  sleep 0.5
done
if [[ ${found:-0} != 1 ]]; then
  echo "install.sh: $ID never showed up in the shell's plugin list after rescan" >&2
  exit 1
fi

omarchy plugin enable "$ID"

# ------------------------------------------------------------- Hyprland wiring

[[ -f "$HYPR_DIR/hyprland.lua" ]] || { echo "install.sh: $HYPR_DIR/hyprland.lua not found" >&2; exit 1; }

# Window rule: float, 400x394, top-right corner. `move` uses Omarchy's table
# form with monitor/window variables (the string form `100%-w-20` is not
# honoured by the hyprland-lua bridge on this Hyprland build).
replace_block "$HYPR_DIR/hyprland.lua" \
  'o.window({ title = "^(HW Monitor)$" }, { float = true, size = { 400, 394 }, move = { "(monitor_w-window_w-20)", "(20)" } })'

# SUPER+F5 toggles the plugin panel.
replace_block "$HYPR_DIR/bindings.lua" \
  "o.bind(\"SUPER + F5\", \"HW Monitor\", \"$TOGGLE_CMD\")"

echo "== reloading Hyprland config"
hyprctl reload >/dev/null 2>&1 || { echo "! hyprctl reload failed" >&2; exit 1; }
sleep 0.3
if errors=$(hyprctl configerrors); then
  echo "$errors"
else
  echo "! could not read hyprctl configerrors" >&2
fi

echo "== installed. Toggle with SUPER+F5 (or: $TOGGLE_CMD)."
echo "   Uninstall with: $0 uninstall"
