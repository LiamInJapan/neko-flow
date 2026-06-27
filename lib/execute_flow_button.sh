#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths
neko_flow_source_actions
neko_flow_source_button_actions

BUTTON_ID="${1:-}"
MODE="${2:-}"
SUBSTATE="${3:-}"

[[ -n "$BUTTON_ID" ]] || {
  echo "usage: execute_flow_button.sh BUTTON_ID [MODE] [SUBSTATE]" >&2
  exit 2
}

spec=""
if declare -F neko_flow_button_spec >/dev/null 2>&1; then
  spec="$(neko_flow_button_spec "$BUTTON_ID" || true)"
fi

if [[ -z "$spec" ]]; then
  hint="Please wire this up when ready."
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Neko Flow · ${BUTTON_ID}" "$hint" -a "Neko Flow" -t 7000
  else
    echo "neko flow: no action for [${BUTTON_ID}] — ${hint}" >&2
  fi
  exit 0
fi

if declare -F neko_dispatch_flow_button_spec >/dev/null 2>&1; then
  neko_dispatch_flow_button_spec "$spec"
else
  echo "neko flow: neko_flow_actions.sh missing (cannot run ${spec})" >&2
  exit 1
fi

exit 0
