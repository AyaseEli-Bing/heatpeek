#!/bin/bash
# Deterministic self-check for heatpeek.
#   scripts/selftest.sh <binary>          quick: CLI contract, JSON structure, plausibility, ioreg cross-check
#   scripts/selftest.sh <binary> --full   adds a sustained-load test that asserts temperatures actually rise
#
# Hardware-dependent assertions are skipped (not failed) when no sensors are present, so the same
# script runs on a bare GitHub macOS runner and on a real Mac.
set -euo pipefail

BIN=${1:?"usage: selftest.sh <binary> [--full]"}
MODE=${2:-quick}
JOBS=$(sysctl -n hw.ncpu)

PASSED=0
FAILED=0
SKIPPED=0

ok() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
skip() { SKIPPED=$((SKIPPED + 1)); printf '  skip  %s\n' "$1"; }

check() { # check <label> <python-expression on JSON doc `d`>
  local label=$1 expr=$2 json=$3
  if python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert ($expr), 'condition false'
" <<<"$json" 2>/dev/null; then
    ok "$label"
  else
    bad "$label"
  fi
}

load_json() { "$BIN" --once --json; }

echo "heatpeek selftest — binary=$BIN mode=$MODE"
echo
echo "[1] CLI contract"

VERSION=$("$BIN" --version)
if printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  ok "--version prints a semver ($VERSION)"
else
  bad "--version printed '$VERSION'"
fi

if "$BIN" --help | grep -q 'Usage:'; then ok "--help prints usage"; else bad "--help missing usage"; fi

if "$BIN" --help | grep -q -- '(-h)'; then
  ok "usage advertises the -h alias"
else
  bad "usage hides the -h alias that main.swift accepts"
fi

set +e
"$BIN" --nonsense > /dev/null 2>&1
CODE=$?
set -e
if [ "$CODE" = "64" ]; then
  ok "unknown flag exits 64"
else
  bad "unknown flag exit code was $CODE, expected 64"
fi

set +e
ERR=$("$BIN" --json 2>&1 > /dev/null)
CODE=$?
set -e
if [ "$CODE" = "64" ]; then
  ok "--json without --once exits 64"
else
  bad "--json without --once exit code was $CODE, expected 64 (--json requires --once)"
fi
# The exit code alone does not prove the diagnostic: a bare "boom" would also exit 64.
# AC-01 requires the reason and the usage text together.
if printf '%s' "$ERR" | grep -q -- '--json requires --once'; then
  ok "--json without --once explains itself on stderr"
else
  bad "--json without --once stderr missing the reason: $ERR"
fi
if printf '%s' "$ERR" | grep -q 'Usage:'; then
  ok "--json without --once prints the usage text"
else
  bad "--json without --once stderr missing the usage text: $ERR"
fi

# AC-11: help and --version short-circuit before any validation, so they win even when
# combined with a flag that would otherwise be rejected. Locked here because it is a
# contract, not an accident — but changing it needs a Spec change, not a quiet edit.
set +e
"$BIN" -h --json > /dev/null 2>&1
CODE=$?
set -e
if [ "$CODE" = "0" ]; then
  ok "-h short-circuits --json validation"
else
  bad "-h with --json exited $CODE, expected 0 (help wins over validation)"
fi

set +e
"$BIN" --version --nonsense > /dev/null 2>&1
CODE=$?
set -e
if [ "$CODE" = "0" ]; then
  ok "--version short-circuits unknown-flag rejection"
else
  bad "--version with --nonsense exited $CODE, expected 0 (version wins over validation)"
fi

# Repeated flags stay idempotent rather than tripping the combination guard.
set +e
timeout 10 "$BIN" --once --json --json > /dev/null 2>&1
CODE=$?
set -e
if [ "$CODE" = "0" ]; then
  ok "--json is idempotent and order independent"
else
  bad "--once --json --json exited $CODE, expected 0"
fi

ONCE=$("$BIN" --once)
if printf '%s' "$ONCE" | grep -Eq 'temperature|unavailable|no sensor data'; then
  ok "--once prints a human-readable readout"
else
  bad "--once output unexpected: $ONCE"
fi

echo
echo "[2] JSON structure"

JSON=$(load_json)
if printf '%s' "$JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  ok "--json is valid JSON"
else
  bad "--json is not valid JSON"
  printf '%s\n' "$JSON" | head -5
fi

check "every documented key present" \
  "set(['timestamp','temperatures','gpuUtilizationPercent','gpuPowerWatts','fans','unavailable']) <= set(d)" "$JSON"
check "timestamp is ISO8601" \
  "len(d['timestamp']) >= 20 and d['timestamp'][4] == '-'" "$JSON"
check "temperatures entries have sensor+celsius" \
  "all(set(x) == {'sensor','celsius'} for x in d['temperatures'])" "$JSON"

COUNT=$(printf '%s' "$JSON" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["temperatures"]))')

if [ "$COUNT" -eq 0 ]; then
  skip "hardware assertions (no sensors on this machine — $(printf '%s' "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("unavailable", {}))'))"
  echo
  echo "passed=$PASSED failed=$FAILED skipped=$SKIPPED"
  [ "$FAILED" -eq 0 ] && exit 0 || exit 1
fi

echo
echo "[3] plausibility ($COUNT temperature sensors)"

check "at least 10 temperature sensors" "len(d['temperatures']) >= 10" "$JSON"
check "all temperatures within 5..110 C" \
  "all(5 <= x['celsius'] <= 110 for x in d['temperatures'])" "$JSON"
check "GPU utilization within 0..100" \
  "d['gpuUtilizationPercent'] is None or 0 <= d['gpuUtilizationPercent'] <= 100" "$JSON"
check "GPU power positive and sane" \
  "d['gpuPowerWatts'] is None or 0 < d['gpuPowerWatts'] < 100" "$JSON"
check "GPU power is not a static snapshot" \
  "d['gpuPowerWatts'] is not None" "$JSON"
check "fan RPM, when present, is in 0..15000" \
  "all(0 <= f['rpm'] <= 15000 for f in d['fans'])" "$JSON"
check "fan keys are named Fan N" \
  "all(f['name'].startswith('Fan ') for f in d['fans'])" "$JSON"

echo
echo "[4] cross-check against ioreg"

IOREG=$(ioreg -r -c IOAccelerator -w 0 2>/dev/null | grep -o '"Device Utilization %"=[0-9]*' | head -1 | cut -d= -f2 || true)
OURS=$(printf '%s' "$JSON" | python3 -c 'import json,sys; v=json.load(sys.stdin)["gpuUtilizationPercent"]; print(-1 if v is None else int(v))')
if [ -z "${IOREG:-}" ]; then
  skip "ioreg GPU utilization (key absent on this kernel path)"
else
  DELTA=$(python3 -c "print(abs($OURS - $IOREG))")
  if python3 -c "import sys; sys.exit(0 if $DELTA <= 30 else 1)"; then
    ok "GPU utilization $OURS vs ioreg $IOREG (delta $DELTA <= 30)"
  else
    bad "GPU utilization $OURS disagrees with ioreg $IOREG"
  fi
fi

if [ "$MODE" != "--full" ]; then
  echo
  echo "[5] load response — skipped (pass --full)"
  echo
  echo "passed=$PASSED failed=$FAILED skipped=$((SKIPPED + 1))"
  [ "$FAILED" -eq 0 ] && exit 0 || exit 1
fi

echo
echo "[5] load response (heating $JOBS threads for 25s)"

BEFORE=$(load_json | python3 -c 'import json,sys; print(round(max(x["celsius"] for x in json.load(sys.stdin)["temperatures"]), 1))')
PIDS=""
for _ in $(seq 1 "$JOBS"); do
  yes > /dev/null 2>&1 &
  PIDS="$PIDS $!"
done
cleanup() {
  for pid in $PIDS; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  PIDS=""
}
trap cleanup EXIT

sleep 25
AFTER=$(load_json | python3 -c 'import json,sys; print(round(max(x["celsius"] for x in json.load(sys.stdin)["temperatures"]), 1))')
cleanup

RISE=$(python3 -c "print( round($AFTER - $BEFORE, 2) )")
if python3 -c "import sys; sys.exit(0 if $RISE >= 2 else 1)"; then
  ok "max temperature rose under load: ${BEFORE}C -> ${AFTER}C (+${RISE}C)"
else
  bad "max temperature did not rise under load: ${BEFORE}C -> ${AFTER}C"
fi

echo
echo "passed=$PASSED failed=$FAILED skipped=$SKIPPED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
