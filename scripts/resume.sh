#!/usr/bin/env bash
# Relaunches Auggie conversations that were running when the Herdr server
# stopped. Herdr restores the layout but only resumes official integrations.
set -u
. "$(dirname "$0")/common.sh"

dir="$(state_dir)"
[ -d "$dir" ] || exit 0

resumed=0
launched=""
for f in "$dir"/*.json; do
  [ -e "$f" ] || continue
  pane="$(jq -r .pane "$f")" conv="$(jq -r .conversation "$f")" cwd="$(jq -r .cwd "$f")"
  [ -n "$conv" ] && [ -d "$cwd" ] || { rm -f "$f"; continue; }

  # Never open the same conversation twice: skip it if another pane already
  # runs it or this loop just relaunched it.
  case " $launched " in *" $conv "*) rm -f "$f"; continue ;; esac
  other="$(pane_with_conversation "$conv")" && [ "$other" != "$pane" ] && { rm -f "$f"; continue; }

  info="$(h pane get "$pane" 2>/dev/null)"
  if [ -z "$info" ]; then
    pane="$(h workspace create --cwd "$cwd" --label "$(basename "$cwd")" --no-focus 2>/dev/null \
      | jq -r '.result.root_pane.pane_id // empty')"
    [ -n "$pane" ] || continue
    rm -f "$f"
  elif [ -n "$(printf '%s' "$info" | jq -r '.result.pane.agent // empty')" ]; then
    continue
  fi

  # Auggie does not save a session until the first exchange; start fresh then.
  resume_arg=""
  [ -e "${AUGMENT_CACHE_DIR:-$HOME/.augment}/sessions/$conv.json" ] && resume_arg=" --resume $conv"
  [ -n "$resume_arg" ] || rm -f "$f"
  h pane run "$pane" "cd $(printf '%q' "$cwd") && $(auggie_cmd)$resume_arg" >/dev/null \
    && resumed=$((resumed + 1)) && launched="$launched $conv"
done
echo "herdr-auggie: resumed $resumed session(s)"
