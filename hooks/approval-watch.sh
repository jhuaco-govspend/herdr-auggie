#!/usr/bin/env bash
# Watches a pane while one Auggie tool call is pending and reports "blocked"
# while the approval dialog is on screen. Auggie has no hook for that moment.
# Exits when the marker for this tool call disappears or changes.
set -u
pane="$1" marker="$2" token="$3" conv="${4:-}"
herdr="${HERDR_BIN_PATH:-herdr}"
blocked=0

now_ns() { local t; t="$(date +%s%N)"; case "$t" in *N) perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1e9' ;; *) echo "$t" ;; esac; }

report() {
  "$herdr" pane report-agent "$pane" --source custom:auggie --agent auggie \
    --seq "$(now_ns)" --state "$1" ${conv:+--agent-session-id "$conv"} >/dev/null 2>&1
}

for _ in $(seq 1 3600); do
  sleep 1
  [ "$(cat "$marker" 2>/dev/null)" = "$token" ] || exit 0
  if "$herdr" pane read "$pane" --source visible --lines 25 2>/dev/null \
      | grep -q "Tool Approval Required"; then
    [ "$blocked" = 0 ] && report blocked && blocked=1
  elif [ "$blocked" = 1 ]; then
    report working && blocked=0
  fi
done
