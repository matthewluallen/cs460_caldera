#!/usr/bin/env bash
# CS460 Module 4 — pre-build Caldera (OT) at Codespace creation.
# Runs once (onCreateCommand). Clear progress markers are printed so the
# Codespace "Creating..." log shows exactly how far it got.
set -uo pipefail

CALDERA_TAG="5.3.0"
ROOT="$(pwd)"              # /workspaces/cs460_caldera
say(){ echo "=== [setup-caldera] $* ==="; }

say "START (tag ${CALDERA_TAG}) in ${ROOT}"

# ss for the keep-alive's connection-gating; rsync for robust copies.
say "apt: iproute2 rsync"
sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y iproute2 rsync >/dev/null 2>&1 || echo "apt step had warnings (continuing)"

# ---------------------------------------------------------------------------
# 1. Caldera core (pinned) + submodules
# ---------------------------------------------------------------------------
if [ ! -d caldera ]; then
  say "clone apache/caldera @ ${CALDERA_TAG}"
  git clone https://github.com/apache/caldera.git --branch "${CALDERA_TAG}" --depth 1 --recursive caldera \
    || git clone https://github.com/apache/caldera.git --branch "${CALDERA_TAG}" --recursive caldera
fi
cd caldera
say "submodule sync (retry for the known recursive flakiness)"
git submodule update --init --recursive || git submodule update --init --recursive || true

say "pip install caldera requirements"
pip3 install --no-cache-dir -r requirements.txt || echo "pip caldera had warnings (continuing)"
cd "${ROOT}"

# ---------------------------------------------------------------------------
# 2. caldera-ot plugins: modbus + dnp3
# ---------------------------------------------------------------------------
if [ ! -d caldera-ot ]; then
  say "clone mitre/caldera-ot"
  git clone https://github.com/mitre/caldera-ot.git caldera-ot || echo "caldera-ot clone warning"
fi
cd caldera-ot
# We only need modbus + dnp3 (skip the flaky 'gems'/others).
say "init modbus + dnp3 submodules"
git submodule update --init --recursive modbus dnp3 \
  || { echo "retry modbus/dnp3 submodules"; git submodule update --init --recursive modbus dnp3 || true; }
cd "${ROOT}"

say "copy modbus + dnp3 into caldera/plugins/"
for p in modbus dnp3; do
  if [ -d "caldera-ot/${p}" ]; then
    rsync -a --delete "caldera-ot/${p}/" "caldera/plugins/${p}/"
    echo "  -> caldera/plugins/${p} ($(ls -1 caldera/plugins/${p} | wc -l) entries)"
  else
    echo "  !! caldera-ot/${p} missing — submodule did not populate"
  fi
done

say "pip install plugin requirements (if any)"
for p in modbus dnp3; do
  [ -f "caldera/plugins/${p}/requirements.txt" ] && pip3 install --no-cache-dir -r "caldera/plugins/${p}/requirements.txt" || true
done

# ---------------------------------------------------------------------------
# 3. Enable modbus + dnp3 in conf/default.yml (insecure mode uses default.yml)
# ---------------------------------------------------------------------------
say "enable modbus + dnp3 in conf/default.yml"
python3 - <<'PY'
import re
p = "caldera/conf/default.yml"
try:
    s = open(p).read()
except FileNotFoundError:
    print("  !! conf/default.yml not found"); raise SystemExit(0)

lines = s.splitlines()
out, i, n = [], 0, len(lines)
# find the 'plugins:' block, capture item indent, collect existing names
while i < n and not re.match(r'^plugins:\s*$', lines[i]):
    out.append(lines[i]); i += 1
if i < n:
    out.append(lines[i]); i += 1            # the 'plugins:' line
    indent, existing, block = "- ", set(), []
    while i < n and (re.match(r'^(\s*)-\s*\S+', lines[i]) or lines[i].strip()==""):
        m = re.match(r'^(\s*-\s*)(\S+)', lines[i])
        if m:
            indent = m.group(1); existing.add(m.group(2).strip())
        block.append(lines[i]); i += 1
    for name in ("modbus", "dnp3"):
        if name not in existing:
            block.append(f"{indent}{name}")
    out.extend(block)
out.extend(lines[i:])
open(p, "w").write("\n".join(out) + "\n")
print("  plugins now:", [l.strip() for l in open(p).read().splitlines() if re.match(r'^\s*-\s*(modbus|dnp3)\s*$', l)])
PY

# ---------------------------------------------------------------------------
# 4. Pre-build the Vue (Magma) UI so the first server start is fast
# ---------------------------------------------------------------------------
if [ -d caldera/plugins/magma ]; then
  say "pre-build Magma UI (npm install + build) — this is the slow part"
  ( cd caldera/plugins/magma && npm install && npm run build ) \
    && echo "  -> Magma build OK ($( [ -d caldera/plugins/magma/dist ] && echo dist present || echo 'no dist?'))" \
    || echo "  !! Magma build failed — first 'server.py --build' will build it at runtime"
else
  echo "  !! plugins/magma missing"
fi

# ---------------------------------------------------------------------------
# 5. Tailscale binary (student runs 'sudo tailscale up --authkey' themselves)
# ---------------------------------------------------------------------------
say "install Tailscale binary"
curl -fsSL https://tailscale.com/install.sh | sh || echo "  !! tailscale install warning"

say "DONE"
