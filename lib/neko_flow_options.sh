# Sourced after neko_flow_env.sh and NEKO_PARSER is set.
# Emits one substate label per line — same as Quickshell's meta.options (then defaults if meta empty).

neko_flow_first_option() {
  local m="$1"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line"
    return 0
  done < <(neko_flow_emit_option_lines "$m")
  return 1
}

neko_flow_emit_option_lines() {
  local m="$1"
  [[ -f "${NEKO_PARSER:?}" ]] || return 1
  local json
  # Don't pass NEKO_DOCUMENTS="" to Python. If the env var exists but is empty,
  # neko_flow_doc_parse.py resolves paths relative to Path('') instead of ~/Documents.
  if [[ -n "${NEKO_DOCUMENTS:-}" ]]; then
    json="$(NEKO_DOCUMENTS="$NEKO_DOCUMENTS" python3 "$NEKO_PARSER" meta "$m" 2>/dev/null)" || json=""
  else
    json="$(python3 "$NEKO_PARSER" meta "$m" 2>/dev/null)" || json=""
  fi
  if [[ -n "$json" ]]; then
    # Parse meta JSON from stdin and print one option label per line.
    # Exit 0 only if at least one option was printed; otherwise fall back to defaults.
    if printf '%s' "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); opts=d.get("options") or []; out=[o.strip() for o in opts if isinstance(o,str) and o.strip()]; sys.stdout.write("\n".join(out) + ("\n" if out else "")); sys.exit(0 if out else 1)' 2>/dev/null; then
      return 0
    fi
  fi
  if [[ -n "${NEKO_DOCUMENTS:-}" ]]; then
    NEKO_DOCUMENTS="$NEKO_DOCUMENTS" python3 "$NEKO_PARSER" defaults "$m" 2>/dev/null || return 1
  else
    python3 "$NEKO_PARSER" defaults "$m" 2>/dev/null || return 1
  fi
}
