# Shared helpers for herdr-auggie scripts. Sourced, not executed.

# Herdr session name: explicit, else derived from the socket path. Named
# sessions live in .../sessions/<name>/herdr.sock, the default one does not.
herdr_session() {
  local dir="$(dirname "${HERDR_SOCKET_PATH:-/x}")"
  if [ -n "${HERDR_SESSION:-}" ]; then
    echo "$HERDR_SESSION"
  elif [ "$(basename "$(dirname "$dir")")" = sessions ]; then
    basename "$dir"
  else
    echo default
  fi
}

# Runs the herdr CLI against the current session.
h() {
  local bin="${HERDR_BIN_PATH:-$(command -v herdr)}"
  if [ -n "${HERDR_SOCKET_PATH:-}" ]; then
    "$bin" "$@"
  else
    "$bin" --session "$(herdr_session)" "$@"
  fi
}

state_dir() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/herdr-auggie/$(herdr_session)"
}

# Working directory of the pane the user is looking at.
current_cwd() {
  local pane="${HERDR_PANE_ID:-}"
  [ -n "$pane" ] || pane="$(h pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty')"
  [ -n "$pane" ] && h pane get "$pane" 2>/dev/null | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty'
}

# Prints the pane already running a conversation, if any.
pane_with_conversation() {
  local f pane
  for f in "$(state_dir)"/*.json; do
    [ -e "$f" ] || continue
    [ "$(jq -r .conversation "$f")" = "$1" ] || continue
    pane="$(jq -r .pane "$f")"
    if [ -n "$(h pane get "$pane" 2>/dev/null | jq -r '.result.pane.agent // empty')" ]; then
      echo "$pane"
      return 0
    fi
  done
  return 1
}

auggie_cmd() {
  echo "auggie --allow-indexing${AUGGIE_HERDR_ARGS:+ $AUGGIE_HERDR_ARGS}"
}
