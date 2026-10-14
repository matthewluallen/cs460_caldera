#!/usr/bin/env bash
# Connection-gated keep-alive for the CS460 Module 4 Caldera Codespace.
# Prints to this terminal (which resets the Codespace idle timer) ONLY while the
# Caldera web UI port has an active browser connection (default 8888). After the
# tab disconnects it waits a short grace window, then stops, so the Codespace
# idle-times-out normally. A hard cap bounds total keep-alive time in case a tab
# is left open and abandoned.
#
# NOTE: a fresh Caldera repo Codespace usually has no 'ss' (iproute2) installed,
# so in practice the fallback time-bound below runs and heartbeats for the whole
# class. The default cap is generous (4 h). Tune via Codespaces variables:
#   KEEPALIVE_PORTS      space-separated ports to watch (default: 8888)
#   KEEPALIVE_GRACE_MIN  minutes to stay awake after last connection (default: 10)
#   KEEPALIVE_CAP_MIN    hard cap on total keep-alive minutes       (default: 240)
PORTS="${KEEPALIVE_PORTS:-8888}"
GRACE_MIN="${KEEPALIVE_GRACE_MIN:-10}"
CAP_MIN="${KEEPALIVE_CAP_MIN:-240}"

if ! command -v ss >/dev/null 2>&1; then
  echo "keep-alive: 'ss' not found; falling back to a ${CAP_MIN}m time-bound."
  for i in $(seq 1 "$CAP_MIN"); do echo "keep-alive (fallback) $i/${CAP_MIN} - $(date)"; sleep 60; done
  exit 0
fi

filter=""
for p in $PORTS; do
  [ -n "$filter" ] && filter="$filter or "
  filter="${filter}sport = :$p or dport = :$p"
done

active_conns() { ss -Htn state established "( $filter )" 2>/dev/null | wc -l; }

echo "keep-alive: watching ports [$PORTS], grace=${GRACE_MIN}m, cap=${CAP_MIN}m"
start=$(date +%s); last_active=$start
while :; do
  now=$(date +%s)
  (( (now - start)/60 >= CAP_MIN )) && { echo "keep-alive: hit ${CAP_MIN}m cap - stopping; idle timeout now applies."; break; }
  c=$(active_conns)
  if [ "$c" -gt 0 ]; then
    last_active=$now
    echo "keep-alive: $c active service connection(s) - staying awake ($(date +%H:%M:%S))"
  else
    idle=$(( (now - last_active)/60 ))
    if [ "$idle" -lt "$GRACE_MIN" ]; then
      echo "keep-alive: no connections, within ${GRACE_MIN}m grace (${idle}m) - staying awake"
    else
      echo "keep-alive: no service connections for >= ${GRACE_MIN}m - stopping; idle timeout now applies."
      break
    fi
  fi
  sleep 60
done
