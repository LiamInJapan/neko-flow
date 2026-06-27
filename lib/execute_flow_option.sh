#!/usr/bin/env bash
# Super+Alt+Return — toggle executed substate; open mode note in Sublime.
# App opens: contextual [ButtonId] buttons (execute_flow_button.sh).
set -euo pipefail

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths
neko_flow_source_actions

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

options_for_mode() {
  local m="$1"
  [[ -f "$NEKO_PARSER" ]] || return 1
  neko_flow_emit_option_lines "$m"
}

first_option() {
  local -a _fo
  mapfile -t _fo < <(options_for_mode "$1")
  printf '%s\n' "${_fo[0]:-}"
}

neko_option_in_mode_list() {
  local m="$1" want="$2"
  local line
  [[ -z "$want" ]] && return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ "$line" == "$want" ]] && return 0
  done < <(options_for_mode "$m")
  return 1
}

current_option="${current_option//$'\r'/}"
current_option="${current_option#"${current_option%%[![:space:]]*}"}"
current_option="${current_option%"${current_option##*[![:space:]]}"}"

if [[ -z "$current_option" ]] || ! neko_option_in_mode_list "$mode" "$current_option"; then
  current_option="$(first_option "$mode")"
  current_option="${current_option//$'\r'/}"
  current_option="${current_option#"${current_option%%[![:space:]]*}"}"
  current_option="${current_option%"${current_option##*[![:space:]]}"}"
  printf '%s\n' "$current_option" > "$OPTION_FILE"
fi

ts="$(date '+%Y-%m-%d %H:%M:%S')"
toggled_on=0
if NEKO_MODE="$mode" NEKO_OPTION="$current_option" NEKO_TS="$ts" NEKO_JSON="$EXECUTED_FILE" python3 - <<'PY'
import json, os, sys
from pathlib import Path

path = Path(os.environ["NEKO_JSON"])
mode = os.environ["NEKO_MODE"]
option = os.environ["NEKO_OPTION"]
ts = os.environ["NEKO_TS"]
data = {}
if path.exists() and path.stat().st_size > 0:
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {}

prev = data.get(mode)
if isinstance(prev, dict) and prev.get("option") == option:
    data.pop(mode, None)
    path.write_text(json.dumps(data, indent=2) + "\n")
    sys.exit(1)

data[mode] = {"option": option, "ts": ts}
path.write_text(json.dumps(data, indent=2) + "\n")
sys.exit(0)
PY
then
  toggled_on=1
fi

neko_resolve_doc_path() {
  local mode="$1"
  local docs="${NEKO_DOCUMENTS:-$HOME/Documents}"
  local mu="$mode"
  local ml
  ml="$(echo "$mode" | tr '[:upper:]' '[:lower:]')"
  local ext p

  for ext in .md .txt .org; do
    for p in "$docs/$mu$ext" "$docs/$ml$ext"; do
      if [[ -f "$p" ]]; then
        printf '%s\n' "$p"
        return
      fi
    done
  done

  if [[ -f "$docs/$mu" ]]; then
    printf '%s\n' "$docs/$mu"
    return
  fi
  if [[ -f "$docs/$ml" ]]; then
    printf '%s\n' "$docs/$ml"
    return
  fi
  if [[ -d "$docs/$mu" ]]; then
    for p in "$docs/$mu/$mu.md" "$docs/$mu/$ml.md" "$docs/$mu/overview.md" "$docs/$mu/README.md"; do
      if [[ -f "$p" ]]; then
        printf '%s\n' "$p"
        return
      fi
    done
    printf '%s\n' "$docs/$mu"
    return
  fi
  if [[ -d "$docs/$ml" ]]; then
    for p in "$docs/$ml/$mu.md" "$docs/$ml/$ml.md" "$docs/$ml/overview.md" "$docs/$ml/README.md"; do
      if [[ -f "$p" ]]; then
        printf '%s\n' "$p"
        return
      fi
    done
    printf '%s\n' "$docs/$ml"
    return
  fi

  printf '%s\n' "$docs/$mu.md"
}

neko_subl_launch() {
  local target="$1"
  local force_new="${2:-}"
  if command -v subl >/dev/null 2>&1; then
    if [[ -d "$target" ]]; then
      subl -a "$target" >/dev/null 2>&1 &
    elif [[ "$force_new" == "new" ]]; then
      subl -n "$target" >/dev/null 2>&1 &
    else
      subl "$target" >/dev/null 2>&1 &
    fi
    return 0
  fi
  if [[ -x /opt/sublime_text/sublime_text ]]; then
    if [[ -d "$target" ]]; then
      /opt/sublime_text/sublime_text -a "$target" >/dev/null 2>&1 &
    elif [[ "$force_new" == "new" ]]; then
      /opt/sublime_text/sublime_text -n "$target" >/dev/null 2>&1 &
    else
      /opt/sublime_text/sublime_text "$target" >/dev/null 2>&1 &
    fi
    return 0
  fi
  if command -v sublime_text >/dev/null 2>&1; then
    if [[ -d "$target" ]]; then
      sublime_text -a "$target" >/dev/null 2>&1 &
    elif [[ "$force_new" == "new" ]]; then
      sublime_text -n "$target" >/dev/null 2>&1 &
    else
      sublime_text "$target" >/dev/null 2>&1 &
    fi
    return 0
  fi
  if command -v flatpak >/dev/null 2>&1; then
    if [[ -d "$target" ]]; then
      flatpak run com.sublimetext.Three -a "$target" >/dev/null 2>&1 &
    elif [[ "$force_new" == "new" ]]; then
      flatpak run com.sublimetext.Three -n "$target" >/dev/null 2>&1 &
    else
      flatpak run com.sublimetext.Three "$target" >/dev/null 2>&1 &
    fi
    return 0
  fi
  return 1
}

neko_subl_run_command() {
  local cmd="$1"
  if command -v subl >/dev/null 2>&1; then
    subl --command "$cmd" >/dev/null 2>&1
    return $?
  fi
  if [[ -x /opt/sublime_text/sublime_text ]]; then
    /opt/sublime_text/sublime_text --command "$cmd" >/dev/null 2>&1
    return $?
  fi
  if command -v sublime_text >/dev/null 2>&1; then
    sublime_text --command "$cmd" >/dev/null 2>&1
    return $?
  fi
  if command -v flatpak >/dev/null 2>&1; then
    flatpak run com.sublimetext.Three --command "$cmd" >/dev/null 2>&1
    return $?
  fi
  return 1
}

neko_hypr_sublime_addresses() {
  hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    cls = (c.get('class') or '').lower()
    if cls == 'smerge':
        continue
    if cls == 'sublime_text' or 'sublimetext' in cls.replace('.', ''):
        a = c.get('address')
        if a:
            print(a)
"
}

neko_sublime_doc_here() {
  export PATH="${HOME}/.local/bin:${HOME}/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

  local mode="$1"
  local target
  target="$(neko_resolve_doc_path "$mode")"

  if [[ "$target" == */* ]]; then
    mkdir -p "$(dirname "$target")" 2>/dev/null || true
  fi

  if [[ -d "$target" ]]; then
    if command -v hyprctl >/dev/null 2>&1; then
      local wid
      wid=$(hyprctl activeworkspace -j 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
      if [[ -n "$wid" ]]; then
        neko_hypr_sublime_addresses | neko_hypr_move_addrs_to_workspace "$wid"
      fi
    fi
    neko_subl_launch "$target" || true
    return
  fi

  local wid=""
  if command -v hyprctl >/dev/null 2>&1; then
    wid=$(hyprctl activeworkspace -j 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
  fi

  local before_file after_file new_addrs
  before_file="$(mktemp)"
  after_file="$(mktemp)"
  new_addrs="$(mktemp)"

  if [[ -n "$wid" ]]; then
    neko_hypr_sublime_addresses >"$before_file"
  else
    : >"$before_file"
  fi

  local subl_cmd
  subl_cmd="$(NEKO_PATH="$target" python3 -c 'import json, os; print("neko_flow_prepare_doc " + json.dumps({"path": os.environ["NEKO_PATH"]}))')"
  neko_subl_run_command "$subl_cmd" || true

  local new_found=0
  if [[ -n "$wid" ]]; then
    local _try
    for _try in 1 2 3 4 5 6 7 8; do
      sleep 0.08
      neko_hypr_sublime_addresses >"$after_file"
      comm -13 <(sort -u "$before_file") <(sort -u "$after_file") >"$new_addrs"
      if [[ -s "$new_addrs" ]]; then
        neko_hypr_move_addrs_to_workspace "$wid" <"$new_addrs"
        new_found=1
        break
      fi
    done
    if [[ "$new_found" -eq 0 ]]; then
      neko_subl_launch "$target" new || true
      sleep 0.25
      neko_hypr_sublime_addresses >"$after_file"
      comm -13 <(sort -u "$before_file") <(sort -u "$after_file") | neko_hypr_move_addrs_to_workspace "$wid"
    fi
  else
    sleep 0.35
  fi

  rm -f "$before_file" "$after_file" "$new_addrs"
}

if [[ "$toggled_on" -eq 1 ]]; then
  neko_sublime_doc_here "$mode"
fi
