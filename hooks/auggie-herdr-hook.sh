#!/usr/bin/env bash
# Reports Auggie lifecycle state to the Herdr pane it runs in.
# Auggie runs this for SessionStart, PromptSubmit, PreToolUse, PostToolUse,
# Stop and SessionEnd. Outside Herdr it exits without doing anything.
set -u

[ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ] || exit 0
herdr="${HERDR_BIN_PATH:-herdr}"

event="${AUGMENT_HOOK_EVENT:-}"
conv="${AUGMENT_CONVERSATION_ID:-}"
if command -v timeout >/dev/null; then payload="$(timeout 2 cat 2>/dev/null || true)"; else payload="$(cat)"; fi
if [ -z "$event" ] && [ -n "$payload" ]; then
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  conv="$(printf '%s' "$payload" | jq -r '.conversation_id // empty' 2>/dev/null)"
fi

source_id="custom:auggie"
# Nanosecond clock for ordering reports; BSD date (macOS) has no %N.
now_ns() { local t; t="$(date +%s%N)"; case "$t" in *N) perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1e9' ;; *) echo "$t" ;; esac; }
seq="$(now_ns)"

# Herdr only resumes official integrations, so keep our own pane -> conversation
# map for herdr-auggie-resume.
session="${HERDR_SESSION:-}"
sock_dir="$(dirname "${HERDR_SOCKET_PATH:-/x}")"
if [ -z "$session" ]; then
  [ "$(basename "$(dirname "$sock_dir")")" = sessions ] && session="$(basename "$sock_dir")" || session=default
fi
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-auggie/$session"
state_file="$state_dir/${HERDR_PANE_ID//:/_}.json"
tool_marker="$state_dir/${HERDR_PANE_ID//:/_}.tool"
remember() {
  mkdir -p "$state_dir"
  jq -n --arg pane "$HERDR_PANE_ID" --arg conv "$conv" --arg cwd "${AUGMENT_PROJECT_DIR:-$PWD}" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{pane:$pane, conversation:$conv, cwd:$cwd, at:$at}' \
    > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}
report() {
  "$herdr" pane report-agent "$HERDR_PANE_ID" --source "$source_id" --agent auggie \
    --seq "$seq" --state "$1" ${conv:+--agent-session-id "$conv"} ${2:+--message "$2"} \
    >/dev/null 2>&1
}

case "$event" in
  SessionStart)
    [ -n "$conv" ] && remember
    [ -n "$conv" ] && "$herdr" pane report-agent-session "$HERDR_PANE_ID" \
      --source "$source_id" --agent auggie --seq "$seq" --agent-session-id "$conv" >/dev/null 2>&1
    report idle
    ;;
  PromptSubmit|PostToolUse)
    [ -n "$conv" ] && [ ! -e "$state_file" ] && remember
    rm -f "$tool_marker"
    report working
    ;;
  PreToolUse)
    [ -n "$conv" ] && [ ! -e "$state_file" ] && remember
    report working
    mkdir -p "$state_dir" && echo "$seq" > "$tool_marker"
    detach=nohup; command -v setsid >/dev/null && detach=setsid
    $detach "$(dirname "$0")/approval-watch.sh" "$HERDR_PANE_ID" "$tool_marker" "$seq" "$conv" \
      </dev/null >/dev/null 2>&1 &
    ;;
  Stop)
    rm -f "$tool_marker"
    cause="$(printf '%s' "$payload" | jq -r '.agent_stop_cause // empty' 2>/dev/null)"
    report idle "${cause:-}"
    ;;
  SessionEnd)
    rm -f "$state_file" "$tool_marker"
    "$herdr" pane release-agent "$HERDR_PANE_ID" --source "$source_id" --agent auggie >/dev/null 2>&1
    ;;
esac
exit 0
