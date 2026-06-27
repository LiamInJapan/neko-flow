#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?usage: set_mode.sh MODE}"

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths

mode_upper="$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"

prev_mode=""
if [[ -f "$MODE_FILE" ]]; then
  prev_mode="$(tr -d '\r\n' <"$MODE_FILE" | awk '{print toupper($0)}')"
fi

if [[ "$prev_mode" != "$mode_upper" ]]; then
  first="$(neko_flow_first_option "$mode_upper" 2>/dev/null || true)"
  if [[ -n "$first" ]]; then
    printf '%s\n' "$first" >"$OPTION_FILE"
  fi
fi

printf '%s\n' "$mode_upper" >"$MODE_FILE"
