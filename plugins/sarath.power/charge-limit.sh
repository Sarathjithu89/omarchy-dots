#!/bin/bash
# omarchy:summary=Battery charge limit control (get/set stop-charging threshold)
# omarchy:args=[current|set <percent>]

set -euo pipefail

POWER_DIR="${OMARCHY_POWER_SUPPLY_PATH:-/sys/class/power_supply}"
RULE_FILE="/etc/udev/rules.d/80-battery-charge-limit.rules"

find_battery() {
  local bat
  for bat in "$POWER_DIR"/BAT*; do
    if [[ -r "$bat/charge_control_end_threshold" ]]; then
      echo "$bat"
      return 0
    fi
  done
  return 1
}

cmd_current() {
  local bat
  if bat="$(find_battery)"; then
    cat "$bat/charge_control_end_threshold"
  else
    echo "100"
  fi
}

cmd_restore() {
  local pct
  pct="$(sed -n 's/.*charge_control_end_threshold}="\([0-9][0-9]*\)".*/\1/p' "$RULE_FILE" 2>/dev/null | head -n 1)"
  if [[ -n "$pct" ]]; then
    cmd_set "$pct"
  fi
}

cmd_set() {
  local pct="$1"
  [[ "$pct" =~ ^[0-9]+$ ]] || { echo "invalid limit: $pct" >&2; exit 1; }
  if (( pct < 50 || pct > 100 )); then
    echo "limit out of range (50-100): $pct" >&2
    exit 1
  fi

  local bat kernel
  bat="$(find_battery)" || { echo "no charge-controllable battery found" >&2; exit 1; }
  kernel="$(basename "$bat")"

  echo "$pct" > "$bat/charge_control_end_threshold"

  if (( pct >= 100 )); then
    rm -f "$RULE_FILE"
  else
    printf 'ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="%s", ATTR{charge_control_end_threshold}="%s"\n' \
      "$kernel" "$pct" > "$RULE_FILE"
  fi
  udevadm control --reload
}

case "${1:-current}" in
  current|get) cmd_current ;;
  restore) cmd_restore ;;
  set) cmd_set "${2:?usage: charge-limit set <percent>}" ;;
  *) echo "usage: charge-limit [current|restore|set <percent>]" >&2; exit 1 ;;
esac