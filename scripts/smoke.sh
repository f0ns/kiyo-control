#!/bin/sh
# Stability smoke test: builds the app and runs it RUNS times for SECONDS each with KIYO_SELFTEST=1,
# which repeatedly runs the main-actor isolation check SwiftUI relies on. Fails on any crash.
# usage: scripts/smoke.sh [runs] [seconds] [extra ENV=value ...]
set -e
cd "$(dirname "$0")/.."
RUNS=${1:-4}; SECONDS_EACH=${2:-30}; shift 2 2>/dev/null || true
scripts/build-app.sh >/dev/null
BIN=build/KiyoControl.app/Contents/MacOS/KiyoControl
for r in $(seq 1 "$RUNS"); do
    pkill -x KiyoControl 2>/dev/null || true
    LOG=build/smoke-$r.log
    env KIYO_SELFTEST=1 "$@" "$BIN" >"$LOG" 2>&1 &
    PID=$!
    for s in $(seq 1 "$SECONDS_EACH"); do
        sleep 1
        if ! kill -0 "$PID" 2>/dev/null; then
            wait "$PID" || code=$?
            echo "FAIL: run $r crashed after ${s}s (exit ${code:-0})"
            grep -v "^$" "$LOG" | tail -20
            exit 1
        fi
    done
    kill "$PID"; wait "$PID" 2>/dev/null || true
    echo "run $r ok"
done
echo "PASS: $RUNS x ${SECONDS_EACH}s"
