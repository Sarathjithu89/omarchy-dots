#!/bin/bash
# restore.sh — restore this Omarchy setup onto a fresh system.
#
# Copies the custom shell plugins, bar layout (shell.json), fonts
# (shell.toml), automation hooks, the "Breeze Dark" theme, the extended
# menu, branding, and default agent into ~/.config/omarchy/, then applies
# the theme and reloads the shell.
#
# Existing config is backed up to ~/.config/omarchy/.backups/<timestamp>
# before anything is overwritten.
#
# Usage:
#   ./install.sh             preview + confirm before touching anything
#   ./install.sh --yes       restore without confirmation

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CFG="${HOME}/.config/omarchy"
PLUGINS_DIR="${OMARCHY_CFG}/plugins"
BACKUP_DIR="${OMARCHY_CFG}/.backups/$(date +%Y%m%d%H%M%S)"

ASSUME_YES=0
[[ ${1:-} == "--yes" || ${1:-} == "-y" ]] && ASSUME_YES=1

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

command -v omarchy >/dev/null 2>&1 || fail "omarchy not found on PATH"
[[ -d ${OMARCHY_CFG} ]] || echo "install.sh: note: ${OMARCHY_CFG} does not exist yet (will be created)"

echo "Installation preview"
echo "  Plugins : $(find "$REPO_DIR/plugins" -mindepth 1 -maxdepth 1 -type d | wc -l)"
echo "  Hooks   : $(find "$REPO_DIR/hooks" -mindepth 1 -maxdepth 1 -type d | wc -l)"
echo "  Theme   : Breeze Dark (colors.toml, icons.theme)"
echo "  Config  : shell.json, shell.toml"
echo "  Extras  : extensions/omarchy-menu.jsonc, branding/, defaults/agent"
echo "  Backup  : $BACKUP_DIR"

if (( ! ASSUME_YES )); then
  [[ -t 0 ]] || fail "not interactive; pass --yes"
  read -r -p "Restore this setup? [y/N] " answer
  [[ ${answer,,} == "y" || ${answer,,} == "yes" ]] || { echo "Aborted."; exit 1; }
fi

mkdir -p "$PLUGINS_DIR" "$OMARCHY_CFG/hooks" "$OMARCHY_CFG/themes" \
  "$OMARCHY_CFG/extensions" "$OMARCHY_CFG/branding" "$OMARCHY_CFG/defaults"

# 1. Back up everything we are about to touch.
mkdir -p "$BACKUP_DIR"
for path in plugins shell.json shell.toml hooks themes extensions branding defaults; do
  if [[ -e ${OMARCHY_CFG}/${path} ]]; then
    cp -a "${OMARCHY_CFG}/${path}" "$BACKUP_DIR/"
  fi
done
echo "Backed up existing config to ${BACKUP_DIR}"

# 2. Install custom shell plugins.
for d in "$REPO_DIR"/plugins/*/; do
  id=$(basename "$d")
  rm -rf "$PLUGINS_DIR/$id"
  cp -a "$d" "$PLUGINS_DIR/$id"
  echo "Installed plugin: $id"
done

# 3. Install config files.
cp -a "$REPO_DIR/shell.json" "$REPO_DIR/shell.toml" "$OMARCHY_CFG/"
echo "Restored shell.json and shell.toml"

# 4. Install hooks (merges into existing .d dirs; other hooks are kept).
cp -a "$REPO_DIR/hooks/." "$OMARCHY_CFG/hooks/"
echo "Restored hooks"

# 5. Install the custom theme.
mkdir -p "$OMARCHY_CFG/themes/breeze-dark"
cp -a "$REPO_DIR/theme/." "$OMARCHY_CFG/themes/breeze-dark/"
echo "Restored theme: Breeze Dark"

# 6. Install extras.
cp -a "$REPO_DIR/extensions/." "$OMARCHY_CFG/extensions/"
cp -a "$REPO_DIR/branding/." "$OMARCHY_CFG/branding/"
cp -a "$REPO_DIR/defaults/." "$OMARCHY_CFG/defaults/"
echo "Restored extensions, branding, defaults"

# 7. Apply.
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || echo "install.sh: note: could not restart the shell — run 'omarchy restart shell' manually"
omarchy theme set "Breeze Dark" >/dev/null 2>&1 || echo "install.sh: note: apply the theme manually with: omarchy theme set \"Breeze Dark\""

# 8. Apply the night light's persisted state from shell.json, if present.
if [[ -f ${OMARCHY_CFG}/plugins/sarath.nightlight/apply.sh ]]; then
  entry=$(jq -c '.bar.layout.right[] | select(.id == "sarath.nightlight")' "$OMARCHY_CFG/shell.json" 2>/dev/null || true)
  if [[ -n ${entry} ]]; then
    enabled=$(printf '%s' "$entry" | jq -r 'if .enabled == true then "1" else "0" end' 2>/dev/null || echo 0)
    temp=$(printf '%s' "$entry" | jq -r '.temperature // 4000' 2>/dev/null || echo 4000)
    "$OMARCHY_CFG/plugins/sarath.nightlight/apply.sh" "$enabled" "$temp" >/dev/null 2>&1 || true
  fi
fi

echo "Done. Your Omarchy setup has been restored."