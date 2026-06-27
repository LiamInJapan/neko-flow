# Sourced by neko_flow_paths.sh after NEKO_FLOW_CONFIG_DIR is set.
if [[ -f "${NEKO_FLOW_CONFIG_DIR}/flow_launch_overrides.sh" ]]; then
  # shellcheck source=/dev/null
  . "${NEKO_FLOW_CONFIG_DIR}/flow_launch_overrides.sh"
fi
if [[ -n "${NEKO_DOCUMENTS:-}" ]]; then
  export NEKO_DOCUMENTS
fi
