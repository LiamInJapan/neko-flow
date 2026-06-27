#!/usr/bin/env bash
# Open mode notes in Sublime.
# Usage: open_flow_notes.sh MODE | open_flow_notes.sh --path FILE
set -euo pipefail

# shellcheck source=neko_flow_paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/neko_flow_paths.sh"
neko_flow_init_paths

path=""
if [[ "${1:-}" == "--path" ]]; then
  path="${2:?usage: open_flow_notes.sh --path FILE}"
elif [[ -n "${1:-}" ]]; then
  MODE="$1"
  if [[ -f "$NEKO_PARSER" ]]; then
    if [[ -n "${NEKO_DOCUMENTS:-}" ]]; then
      path="$(NEKO_FLOW_CONFIG_DIR="$NEKO_FLOW_CONFIG_DIR" NEKO_DOCUMENTS="$NEKO_DOCUMENTS" python3 "$NEKO_PARSER" path "$MODE" 2>/dev/null || true)"
    else
      path="$(NEKO_FLOW_CONFIG_DIR="$NEKO_FLOW_CONFIG_DIR" python3 "$NEKO_PARSER" path "$MODE" 2>/dev/null || true)"
    fi
  fi
  if [[ -z "$path" ]]; then
    docs="${NEKO_DOCUMENTS:-$HOME/Documents}"
    path="${docs}/${MODE^^}.md"
  fi
else
  echo "usage: open_flow_notes.sh MODE | open_flow_notes.sh --path FILE" >&2
  exit 2
fi

if [[ ! -e "$path" ]]; then
  mkdir -p "$(dirname "$path")"
  : >"$path"
fi

export PATH="${HOME}/.local/bin:${HOME}/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

if command -v subl >/dev/null 2>&1; then
  subl "$path" >/dev/null 2>&1 &
  exit 0
fi
if [[ -x /opt/sublime_text/sublime_text ]]; then
  /opt/sublime_text/sublime_text "$path" >/dev/null 2>&1 &
  exit 0
fi
if command -v sublime_text >/dev/null 2>&1; then
  sublime_text "$path" >/dev/null 2>&1 &
  exit 0
fi
if command -v flatpak >/dev/null 2>&1; then
  flatpak run com.sublimetext.Three "$path" >/dev/null 2>&1 &
  exit 0
fi

echo "neko: open_flow_notes: no Sublime launcher found for $path" >&2
exit 1
