# Central path resolution for Neko Flow (sourced by all lib scripts).
# Override before sourcing:
#   NEKO_FLOW_LIB_DIR    — installed lib (default: directory containing this file)
#   NEKO_FLOW_CONFIG_DIR — user config (default: ~/.config/neko-flow, or ~/.config/neko if legacy)

neko_flow_init_paths() {
  if [[ -n "${NEKO_FLOW_PATHS_INIT:-}" ]]; then
    return 0
  fi
  NEKO_FLOW_PATHS_INIT=1

  local _here
  _here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  NEKO_FLOW_LIB_DIR="${NEKO_FLOW_LIB_DIR:-$_here}"

  if [[ -z "${NEKO_FLOW_CONFIG_DIR:-}" ]]; then
    if [[ -d "${HOME}/.config/neko-flow" ]]; then
      NEKO_FLOW_CONFIG_DIR="${HOME}/.config/neko-flow"
    elif [[ -d "${HOME}/.config/neko" ]] && [[ ! -d "${HOME}/.config/neko-flow" ]]; then
      NEKO_FLOW_CONFIG_DIR="${HOME}/.config/neko"
    else
      NEKO_FLOW_CONFIG_DIR="${HOME}/.config/neko-flow"
    fi
  fi

  export NEKO_FLOW_LIB_DIR NEKO_FLOW_CONFIG_DIR

  MODE_FILE="${NEKO_FLOW_CONFIG_DIR}/current_mode"
  OPTION_FILE="${NEKO_FLOW_CONFIG_DIR}/current_option"
  EXECUTED_FILE="${NEKO_FLOW_CONFIG_DIR}/flow_executed.json"
  FLOW_MODES_FILE="${FLOW_MODES_FILE:-${NEKO_FLOW_CONFIG_DIR}/flow_modes.txt}"
  NEKO_PARSER="${NEKO_PARSER:-${NEKO_FLOW_LIB_DIR}/neko_flow_doc_parse.py}"

  export MODE_FILE OPTION_FILE EXECUTED_FILE FLOW_MODES_FILE NEKO_PARSER

  mkdir -p "${NEKO_FLOW_CONFIG_DIR}"

  if [[ -f "${NEKO_FLOW_LIB_DIR}/neko_flow_env.sh" ]]; then
    # shellcheck source=/dev/null
    source "${NEKO_FLOW_LIB_DIR}/neko_flow_env.sh"
  fi
  if [[ -f "${NEKO_FLOW_LIB_DIR}/neko_flow_options.sh" ]]; then
    # shellcheck source=/dev/null
    source "${NEKO_FLOW_LIB_DIR}/neko_flow_options.sh"
  fi
}

neko_flow_source_actions() {
  neko_flow_init_paths
  if [[ -f "${NEKO_FLOW_LIB_DIR}/neko_flow_actions.sh" ]]; then
    # shellcheck source=/dev/null
    source "${NEKO_FLOW_LIB_DIR}/neko_flow_actions.sh"
  fi
}

neko_flow_source_button_actions() {
  neko_flow_init_paths
  if [[ -f "${NEKO_FLOW_CONFIG_DIR}/flow_button_actions.sh" ]]; then
    # shellcheck source=/dev/null
    source "${NEKO_FLOW_CONFIG_DIR}/flow_button_actions.sh"
  fi
}
