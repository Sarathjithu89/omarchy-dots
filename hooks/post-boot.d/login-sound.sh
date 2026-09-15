#!/usr/bin/env bash
# Play the freedesktop "service-login" jingle on desktop start. Waits for the
# audio server to be up so the sound never gets dropped at logon.

set -u

for _ in $(seq 1 15); do
  if canberra-gtk-play -i service-login >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done
exit 0