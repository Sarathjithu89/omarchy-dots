#!/bin/bash
# Night light controller — persists the manual on/off state across reboots.
#
# Writes a single always-active profile to ~/.config/hypr/hyprsunset.conf:
#   enabled  -> 00:00 temperature <K>   screen stays warm until turned off
#   disabled -> 00:00 identity          daylight/neutral temperature
# hyprsunset re-reads this file at every login (autostart.lua + the
# post-boot hook), then we live-apply the temperature now via IPC.
#
# Usage: apply.sh <1|0> <temperature>
#   $1 enabled        "1" keeps warmth on, "0" restores identity
#   $2 temperature K  warmth level applied and remembered

set -u

CONFIG="${HOME}/.config/hypr/hyprsunset.conf"
TMP="${CONFIG}.tmp"
ENABLED="${1:-0}"
TEMP="${2:-4000}"

{
  printf '%s\n' \
    '# Night light.' \
    '# Managed by the Night Light control in the status bar (sarath.nightlight);' \
    '# the toggle and warmth slider overwrite this file. State persists.' \
    '' \
    'profile {' \
    '    time = 00:00'

  if [ "$ENABLED" = "1" ]; then
    printf '    temperature = %s\n' "$TEMP"
  else
    printf '    identity = true\n'
  fi

  printf '%s\n' '}'
} > "$TMP"

mv "$TMP" "$CONFIG"

# Ensure hyprsunset is up (normally started at login via autostart.lua;
# the post-boot hook also covers it).
if ! pgrep -x hyprsunset >/dev/null; then
  setsid uwsm-app -- hyprsunset >/dev/null 2>&1 &
  sleep 1
fi

# Live-apply now. hyprsunset applies its configured profile at the end of its
# boot, overriding anything set before then — resend until it sticks, so the
# change is visible immediately. "Off" restores the daylight temperature
# (6500 K), matching omarchy-toggle-nightlight.
OFF_TEMP=6500
TARGET_TEMP="$([ "$ENABLED" = "1" ] && echo "$TEMP" || echo "$OFF_TEMP")"

for _ in $(seq 1 15); do
  hyprctl hyprsunset temperature "$TARGET_TEMP" >/dev/null 2>&1
  sleep 0.3

  CUR=$(hyprctl hyprsunset temperature 2>/dev/null | grep -m1 -oE '[0-9]+')
  [ -n "$CUR" ] && [ "$CUR" = "$TARGET_TEMP" ] && break
done