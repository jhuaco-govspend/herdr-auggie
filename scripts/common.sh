# Shared helpers for herdr-auggie scripts. Sourced, not executed.

# Herdr session name: explicit, else derived from the socket path
# (~/.config/herdr/sessions/<name>/herdr.sock), else "default".
herdr_session() {
  if [ -n "${HERDR_SESSION:-}" ]; then
    echo "$HERDR_SESSION"
  elif [ -n "${HERDR_SOCKET_PATH:-}" ]; then
    basename "$(dirname "$HERDR_SOCKET_PATH")"
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

auggie_cmd() {
  echo "auggie --allow-indexing${AUGGIE_HERDR_ARGS:+ $AUGGIE_HERDR_ARGS}"
}
