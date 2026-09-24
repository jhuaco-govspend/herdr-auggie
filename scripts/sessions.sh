#!/usr/bin/env bash
# Session picker: lists saved Auggie sessions for the current directory and
# resumes the chosen one in a new tab. Runs inside a Herdr popup.
set -u
. "$(dirname "$0")/common.sh"

cwd="$(current_cwd)"
cwd="${cwd:-$PWD}"
scope=()
[ "${1:-}" = "--all" ] && scope=(--all)

rows="$(cd "$cwd" && auggie session list --json -n 50 "${scope[@]}" 2>/dev/null | jq -r '
  (if type == "array" then . else (.sessions // []) end)[]
  | [.sessionId, (.modified[0:16] | sub("T"; " ")), (.workspaceRoot | split("/") | last),
     ((.firstUserMessage // "") | gsub("[\n\t]"; " ") | .[0:80])] | @tsv')"

if [ -z "$rows" ]; then
  echo "No Auggie sessions for $cwd"
  read -r -t 5 _ || true
  exit 0
fi

if command -v fzf >/dev/null; then
  pick="$(printf '%s\n' "$rows" | fzf --delimiter='\t' --with-nth=2.. --reverse \
    --header="Resume Auggie session (enter) - $cwd" | cut -f1)"
else
  lines=(); while IFS= read -r l; do lines+=("$l"); done <<<"$rows"
  select line in "${lines[@]}"; do pick="${line%%$'\t'*}"; break; done
fi
[ -n "${pick:-}" ] || exit 0

"$(dirname "$0")/new-session.sh" "$cwd" "$pick"
