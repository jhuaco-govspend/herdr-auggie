#!/usr/bin/env bash
# Opens a new tab running Auggie in the current pane's directory.
set -u
. "$(dirname "$0")/common.sh"

cwd="${1:-$(current_cwd)}"
cwd="${cwd:-$PWD}"
args=(tab create --cwd "$cwd" --label "auggie" --focus)
[ -n "${HERDR_WORKSPACE_ID:-}" ] && args+=(--workspace "$HERDR_WORKSPACE_ID")

pane="$(h "${args[@]}" | jq -r '.result.root_pane.pane_id // empty')"
[ -n "$pane" ] || { echo "herdr-auggie: could not create a tab" >&2; exit 1; }
h pane run "$pane" "$(auggie_cmd)${2:+ --resume $2}" >/dev/null
