#!/usr/bin/env bash
set -euo pipefail

OPTION="${1:?usage: set_option.sh OPTION_LABEL}"

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths

printf '%s\n' "$OPTION" >"$OPTION_FILE"
