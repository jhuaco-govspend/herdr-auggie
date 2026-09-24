#!/usr/bin/env bash
# Adds (or removes, with --uninstall) the Herdr hook to Auggie's user settings.
# Idempotent: existing herdr-auggie entries are replaced, other hooks are kept.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/hooks/auggie-herdr-hook.sh"
settings="${AUGMENT_SETTINGS:-$HOME/.augment/settings.json}"
mode="${1:-install}"

command -v jq >/dev/null || { echo "herdr-auggie: jq is required" >&2; exit 1; }
chmod +x "$hook"
mkdir -p "$(dirname "$settings")"
[ -s "$settings" ] || echo '{}' > "$settings"
tmp="$settings.tmp.herdr-auggie"

jq --arg cmd "$hook" --arg mode "$mode" '
  def strip: map(.hooks |= map(select(.command | contains("auggie-herdr-hook") | not)))
             | map(select(.hooks | length > 0));
  def entry($tool): (if $tool then {matcher: ".*"} else {} end)
                    + {hooks: [{type: "command", command: $cmd, timeout: 5000}]};
  .hooks //= {}
  | reduce ("SessionStart","PromptSubmit","PreToolUse","PostToolUse","Stop","SessionEnd") as $e (.;
      .hooks[$e] = ((.hooks[$e] // []) | strip)
      | if $mode == "--uninstall" then .
        else .hooks[$e] += [entry($e == "PreToolUse" or $e == "PostToolUse")] end
      | if (.hooks[$e] | length) == 0 then del(.hooks[$e]) else . end)
' "$settings" > "$tmp"

if cmp -s <(jq -S . "$settings") <(jq -S . "$tmp"); then
  rm -f "$tmp"
  exit 0
fi
cp "$settings" "$settings.bak.herdr-auggie"
mv "$tmp" "$settings"

if [ "$mode" = "--uninstall" ]; then
  echo "herdr-auggie: hooks removed from $settings"
else
  echo "herdr-auggie: hooks installed in $settings (backup: $settings.bak.herdr-auggie)"
fi
