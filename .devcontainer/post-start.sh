#!/usr/bin/env bash
# CS460 Module 4 — runs at every Codespace start.
# Ensures the Tailscale daemon is up and installs the one-word 'tsup' helper so
# the student joins the class tailnet with just:
#     tsup
# (We never run 'tailscale up' here — joining with the key is a manual,
# teachable step, and the key must never be baked in.)
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

# One-word join: 'tsup' expands to the full 'tailscale up' with the Codespaces
# secret. It references the env var only — the key value is never written here.
BRC="${HOME}/.bashrc"
if ! grep -q 'cs460-tsup' "${BRC}" 2>/dev/null; then
  cat >> "${BRC}" <<'RC'

# cs460-tsup : join the class tailnet in one word  ->  tsup
tsup() { sudo tailscale up --authkey "$OTSIM_TAILSCALE_AUTHKEY" "$@"; }
RC
  echo "post-start: installed 'tsup' helper in ~/.bashrc"
fi

echo "post-start: done"
