#!/usr/bin/env bash
# run-bounded.sh — portable liveness watchdog for long-running commands.
#
# Runs a command and kills its WHOLE process tree if it stops producing output
# for --stall seconds (a wedge announces itself by going quiet), or after a
# generous --max hard cap. This replaces static timeouts: a healthy build that
# streams progress can run as long as it needs; a hung one dies in ~--stall s.
#
# Why this exists: GNU `timeout` does not exist on macOS, and hand-rolled
# watchdogs tend to leak a background `sleep` that holds stdout open and
# blocks piped callers. This helper polls in the foreground (nothing to leak)
# and kills by process group (children die too).
#
# Usage: run-bounded.sh [--stall SECONDS] [--max SECONDS] -- command [args...]
# Output: streams nothing while running; prints the command's full output at
# the end (callers wanting quiet-on-success filter this themselves).
# Exit: the command's exit code, or 124 if killed by the watchdog.
set -uo pipefail

STALL=120
MAX=1800
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stall) STALL=$2; shift 2 ;;
    --max)   MAX=$2;   shift 2 ;;
    --)      shift; break ;;
    *) echo "usage: run-bounded.sh [--stall s] [--max s] -- command [args...]" >&2; exit 2 ;;
  esac
done
[[ $# -gt 0 ]] || { echo "run-bounded.sh: no command given" >&2; exit 2; }

LOG=$(mktemp "${TMPDIR:-/tmp}/run-bounded-XXXXXX.log")
cleanup() { rm -f "$LOG"; }
trap cleanup EXIT

# Make the child its own process-group leader (perl setpgrp is portable to
# macOS, which has no setsid binary), so `kill -- -PID` reaps the whole tree.
perl -e 'setpgrp(0,0); exec @ARGV; die "exec failed: $!"' "$@" >"$LOG" 2>&1 &
PID=$!
trap 'kill -TERM -- -"$PID" 2>/dev/null; cleanup' INT TERM

kill_group() { # $1 = reason
  kill -TERM -- -"$PID" 2>/dev/null
  sleep 2
  kill -KILL -- -"$PID" 2>/dev/null
  echo "run-bounded: KILLED — $1" >&2
  cat "$LOG"
  exit 124
}

START=$SECONDS
LAST_SIZE=-1
LAST_CHANGE=$SECONDS
while kill -0 "$PID" 2>/dev/null; do
  sleep 1
  SIZE=$(wc -c <"$LOG" 2>/dev/null || echo 0)
  if [[ "$SIZE" != "$LAST_SIZE" ]]; then
    LAST_SIZE=$SIZE
    LAST_CHANGE=$SECONDS
  fi
  (( SECONDS - LAST_CHANGE >= STALL )) && kill_group "no output for ${STALL}s (stalled)"
  (( SECONDS - START >= MAX ))         && kill_group "exceeded hard cap of ${MAX}s"
done

wait "$PID"
EXIT=$?
cat "$LOG"
exit "$EXIT"
