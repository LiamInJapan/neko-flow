#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-next}"

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths

flow_modes=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^\[([^]]+)\] ]]; then
    flow_modes+=("$(echo "${BASH_REMATCH[1]}" | awk '{print toupper($0)}')")
  fi
done < "$FLOW_MODES_FILE"

if [[ ${#flow_modes[@]} -eq 0 ]] && [[ -f "$NEKO_PARSER" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && flow_modes+=("$line")
  done < <(python3 "$NEKO_PARSER" modes 2>/dev/null || true)
fi

if [[ ${#flow_modes[@]} -eq 0 ]]; then
  flow_modes=(WORK COMMS CREATE CLEAN)
fi

current="WORK"
if [[ -f "$MODE_FILE" ]]; then
  current="$(tr -d '\r\n' <"$MODE_FILE" | awk '{print toupper($0)}')"
fi

idx=-1
for i in "${!flow_modes[@]}"; do
  if [[ "${flow_modes[$i]}" == "$current" ]]; then
    idx="$i"
    break
  fi
done
[[ "$idx" -lt 0 ]] && idx=0

case "$DIR" in
  next) idx=$(( (idx + 1) % ${#flow_modes[@]} )) ;;
  prev) idx=$(( (idx - 1 + ${#flow_modes[@]}) % ${#flow_modes[@]} )) ;;
  *) echo "Usage: $0 {next|prev}" >&2; exit 2 ;;
esac

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/set_mode.sh" "${flow_modes[$idx]}"
