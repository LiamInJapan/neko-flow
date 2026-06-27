#!/usr/bin/env bash
# Install Neko Flow to ~/.local/share/neko-flow and ~/.local/bin
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/neko-flow"
CONFIG_DIR="${HOME}/.config/neko-flow"
BIN_DIR="${HOME}/.local/bin"
DEV_MODE=0

usage() {
  cat <<EOF
Usage: install.sh [options]

  --config-dir DIR   User config directory (default: ~/.config/neko-flow)
  --dev              Symlink lib from repo instead of copying (for development)
  -h, --help         Show this help

After install:
  1. Append hypr/keybinds.snippet.conf to your Hyprland keybinds
  2. Copy quickshell/*.qml into your Quickshell tree (see docs/INTEGRATION.md)
  3. Optional: copy sublime/neko_flow_prepare_doc.py to Sublime Packages/User
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir)
      CONFIG_DIR="${2:?}"
      shift 2
      ;;
    --dev)
      DEV_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$INSTALL_DATA" "$CONFIG_DIR" "$BIN_DIR"

if [[ "$DEV_MODE" -eq 1 ]]; then
  ln -sfn "$REPO_ROOT/lib" "$INSTALL_DATA/lib"
else
  mkdir -p "$INSTALL_DATA/lib"
  cp -a "$REPO_ROOT/lib/." "$INSTALL_DATA/lib/"
fi
chmod +x "$INSTALL_DATA/lib"/*.sh 2>/dev/null || true

install -m 644 "$REPO_ROOT/config/flow_modes.txt.example" "$CONFIG_DIR/flow_modes.txt.example"
install -m 644 "$REPO_ROOT/config/flow_button_actions.sh.example" "$CONFIG_DIR/flow_button_actions.sh.example"
install -m 644 "$REPO_ROOT/config/flow_launch_overrides.sh.example" "$CONFIG_DIR/flow_launch_overrides.sh.example"

for pair in \
  "flow_modes.txt:flow_modes.txt.example" \
  "flow_button_actions.sh:flow_button_actions.sh.example" \
  "flow_launch_overrides.sh:flow_launch_overrides.sh.example"
do
  dst="${pair%%:*}"
  src="${pair##*:}"
  if [[ ! -f "$CONFIG_DIR/$dst" ]]; then
    cp "$CONFIG_DIR/$src" "$CONFIG_DIR/$dst"
    echo "Created $CONFIG_DIR/$dst from example"
  fi
done

write_bin() {
  local name="$1"
  local script="$2"
  cat >"$BIN_DIR/$name" <<EOF
#!/usr/bin/env bash
export NEKO_FLOW_LIB_DIR="\${NEKO_FLOW_LIB_DIR:-$INSTALL_DATA/lib}"
export NEKO_FLOW_CONFIG_DIR="\${NEKO_FLOW_CONFIG_DIR:-$CONFIG_DIR}"
exec "\$NEKO_FLOW_LIB_DIR/$script" "\$@"
EOF
  chmod +x "$BIN_DIR/$name"
}

write_bin neko-flow-cycle-mode cycle_mode.sh
write_bin neko-flow-cycle-option cycle_option.sh
write_bin neko-flow-execute execute_flow_option.sh
write_bin neko-flow-button execute_flow_button.sh
write_bin neko-flow-set-mode set_mode.sh
write_bin neko-flow-set-option set_option.sh
write_bin neko-flow-open-notes open_flow_notes.sh

echo ""
echo "Installed Neko Flow"
echo "  lib:    $INSTALL_DATA/lib"
echo "  config: $CONFIG_DIR"
echo "  bin:    $BIN_DIR/neko-flow-*"
echo ""
echo "Next: see docs/INTEGRATION.md for Hyprland + Quickshell setup."
