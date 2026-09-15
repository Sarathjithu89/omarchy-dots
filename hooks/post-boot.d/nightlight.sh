#!/bin/bash
# Re-apply the persisted night light state after every login so the manual
# on/off + warmth choice survives reboots even if hyprsunset's own boot
# re-application is delayed or overridden.
set -u

CFG="${HOME}/.config/omarchy/shell.json"
APPLY="${HOME}/.config/omarchy/plugins/sarath.nightlight/apply.sh"

[ -f "$CFG" ] || exit 0
[ -f "$APPLY" ] || exit 0

ENTRY=$(jq -c '.bar.layout.right[] | select(.id == "sarath.nightlight")' "$CFG" 2>/dev/null) || exit 0
ENABLED=$(printf '%s' "$ENTRY" | jq -r 'if .enabled == true then "1" else "0" end' 2>/dev/null)
TEMP=$(printf '%s' "$ENTRY" | jq -r '.temperature // 4000' 2>/dev/null)
[ -n "$ENABLED" ] || exit 0

exec "$APPLY" "$ENABLED" "${TEMP:-4000}"