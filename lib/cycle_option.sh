#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-next}"

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths

if [[ ! -f "$NEKO_PARSER" ]]; then
  echo "neko: cycle_option: missing parser: $NEKO_PARSER" >&2
  exit 1
fi

read_mode() {
  if [[ -f "$MODE_FILE" ]]; then
    tr -d '\r\n' <"$MODE_FILE" | awk '{print toupper($0)}'
  else
    echo "WORK"
  fi
}

read_option() {
  if [[ -f "$OPTION_FILE" ]]; then
    tr -d '\r\n' <"$OPTION_FILE"
  else
    echo ""
  fi
}

mode="$(read_mode)"
current_option="$(read_option)"
current_option="${current_option//$'\r'/}"
current_option="${current_option#"${current_option%%[![:space:]]*}"}"
current_option="${current_option%"${current_option##*[![:space:]]}"}"

options=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  options+=("$line")
done < <(neko_flow_emit_option_lines "$mode")

if [[ ${#options[@]} -eq 0 ]]; then
  echo "neko: cycle_option: no options for mode $mode" >&2
  exit 1
fi

idx=-1
for i in "${!options[@]}"; do
  if [[ "${options[$i]}" == "$current_option" ]]; then
    idx="$i"
    break
  fi
done
[[ "$idx" -lt 0 ]] && idx=0

case "$DIR" in
  next) idx=$(( (idx + 1) % ${#options[@]} )) ;;
  prev) idx=$(( (idx - 1 + ${#options[@]}) % ${#options[@]} )) ;;
  *) echo "Usage: $0 {next|prev}" >&2; exit 2 ;;
esac

printf '%s\n' "${options[$idx]}" > "$OPTION_FILE"
