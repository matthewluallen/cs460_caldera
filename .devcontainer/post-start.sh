#!/usr/bin/env bash
# CS460 Module 4 — runs at every Codespace start.
# Ensures the Tailscale daemon is up so the student only needs:
#     sudo tailscale up --authkey "${OTSIM_TAILSCALE_AUTHKEY}"
# (We never start 'tailscale up' here — joining the tailnet with the key is a
# manual, teachable step, and the key must never be baked in.)
set -uo pipefail

if command -v tailscaled >/dev/null 2>&1; then
  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    echo "post-start: starting tailscaled"
    sudo mkdir -p /var/lib/tailscale
    if [ -c /dev/net/tun ]; then
      sudo nohup tailscaled --state=/var/lib/tailscale/tailscaled.state >/tmp/tailscaled.log 2>&1 &
    else
      # No tun device granted — fall back to userspace networking.
      sudo nohup tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state >/tmp/tailscaled.log 2>&1 &
    fi
    sleep 2
  else
    echo "post-start: tailscaled already running"
  fi
fi
echo "post-start: done"
