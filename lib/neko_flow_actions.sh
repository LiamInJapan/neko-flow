#!/usr/bin/env bash
# Shared Hyprland / Firefox / Slack / Discord launch helpers for Neko Flow.
# Sourced by execute_flow_button.sh (app opens) and execute_flow_option.sh (Hyprland + Sublime only).
# Active Hyprland workspace id, or empty if unavailable.
neko_hypr_active_workspace_id() {
  hyprctl activeworkspace -j 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true
}

# Client addresses whose WM class (lowercased) contains substring \$1 (e.g. firefox, discord).
neko_hypr_addrs_class_substr() {
  local sub="$1"
  hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
sub = (sys.argv[1] or '').lower()
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    cls = (c.get('class') or '').lower()
    if sub and sub in cls:
        a = c.get('address')
        if a:
            print(a)
" "$sub"
}

# After spawning an app, poll for new Hypr clients matching class substring; move them to workspace \$1.
# \$2 = class substring, \$3 = path to file listing addresses before launch (one per line).
neko_hypr_poll_move_new_matching() {
  local wid="$1"
  local sub="$2"
  local before_file="$3"
  local after_file new_addrs _try had_baseline addr
  after_file="$(mktemp)"
  new_addrs="$(mktemp)"
  had_baseline=0
  [[ -s "$before_file" ]] && had_baseline=1
  for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 0.08
    neko_hypr_addrs_class_substr "$sub" >"$after_file"
    if [[ "$had_baseline" -eq 0 ]]; then
      # No pre-existing Firefox clients: comm would classify every window as "new". Move only what Firefox focuses.
      addr="$(neko_hypr_focused_firefox_address)"
      [[ -z "$addr" ]] && addr="$(neko_hypr_activewindow_firefox_address)"
      if [[ -n "$addr" ]]; then
        neko_hypr_move_and_focus_addr "$wid" "$addr"
        rm -f "$after_file" "$new_addrs"
        return 0
      fi
      continue
    fi
    comm -13 <(sort -u "$before_file") <(sort -u "$after_file") >"$new_addrs"
    if [[ -s "$new_addrs" ]]; then
      neko_hypr_pick_and_move_one_new_ff "$wid" "$new_addrs"
      rm -f "$after_file" "$new_addrs"
      return 0
    fi
  done
  rm -f "$after_file" "$new_addrs"
  return 1
}

# Address of the Hyprland client that is both focused and Firefox (after firefox raises the window with the tab).
neko_hypr_focused_firefox_address() {
  hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    if not c.get('focused'):
        continue
    cls = (c.get('class') or '').lower()
    if 'firefox' in cls:
        a = c.get('address')
        if a:
            print(a)
            break
"
}

# Same, but from activewindow (fallback if focused flag lags).
neko_hypr_activewindow_firefox_address() {
  hyprctl activewindow -j 2>/dev/null | python3 -c "
import json, sys
try:
    w = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cls = (w.get('class') or '').lower()
if 'firefox' in cls:
    a = w.get('address')
    if a:
        print(a)
"
}

neko_hypr_move_and_focus_addr() {
  local wid="$1"
  local addr="$2"
  if [[ -z "$wid" ]] || [[ -z "$addr" ]]; then
    return 1
  fi
  hyprctl dispatch movetoworkspacesilent "${wid},address:${addr}" >/dev/null 2>&1 || true
  hyprctl dispatch focuswindow "address:${addr}" >/dev/null 2>&1 || true
}

# Move exactly one Firefox client from a "new addresses" set. If comm wrongly lists every window
# (empty baseline snapshot), we must not move them all — pick focused Firefox if it is in the set,
# otherwise the last line (typical newest window).
neko_hypr_pick_and_move_one_new_ff() {
  local wid="$1"
  local new_addrs_file="$2"
  local n addr
  [[ -s "$new_addrs_file" ]] || return 1
  n="$(wc -l <"$new_addrs_file" | tr -d ' ')"
  if [[ "$n" -eq 1 ]]; then
    addr="$(head -n1 "$new_addrs_file")"
    neko_hypr_move_and_focus_addr "$wid" "$addr"
    return 0
  fi
  sleep 0.06
  addr="$(neko_hypr_focused_firefox_address)"
  [[ -z "$addr" ]] && addr="$(neko_hypr_activewindow_firefox_address)"
  if [[ -n "$addr" ]] && grep -Fxq "$addr" "$new_addrs_file" 2>/dev/null; then
    neko_hypr_move_and_focus_addr "$wid" "$addr"
    return 0
  fi
  addr="$(tail -n1 "$new_addrs_file")"
  neko_hypr_move_and_focus_addr "$wid" "$addr"
  return 0
}

# Open URL in Firefox: new top-level window for the URL, then move only Hypr clients that were not present
# before launch (see neko_hypr_poll_move_new_matching).
open_in_firefox() {
  local url="$1"
  if command -v firefox >/dev/null 2>&1; then
    if ! command -v hyprctl >/dev/null 2>&1; then
      firefox --new-window "$url" >/dev/null 2>&1 &
      return 0
    fi

    local wid before_file
    wid="$(neko_hypr_active_workspace_id)"
    if [[ -z "$wid" ]]; then
      firefox --new-window "$url" >/dev/null 2>&1 &
      return 0
    fi

    before_file="$(mktemp)"
    neko_hypr_addrs_class_substr firefox >"$before_file"
    firefox --new-window "$url" >/dev/null 2>&1 &
    if [[ -n "${NEKO_FF_HYPR_WAIT:-}" ]]; then
      sleep "$NEKO_FF_HYPR_WAIT"
    fi
    neko_hypr_poll_move_new_matching "$wid" firefox "$before_file" || true
    rm -f "$before_file"
    return 0
  fi
  xdg-open "$url" >/dev/null 2>&1 &
}
neko_hypr_move_addrs_to_workspace() {
  local wid="$1"
  local do_focus="${2:-1}"
  local addr last=""
  while IFS= read -r addr; do
    [[ -z "$addr" ]] && continue
    hyprctl dispatch movetoworkspacesilent "${wid},address:${addr}" >/dev/null 2>&1 || true
    last="$addr"
  done
  if [[ "$do_focus" != "0" ]] && [[ -n "$last" ]]; then
    hyprctl dispatch focuswindow "address:${last}" >/dev/null 2>&1 || true
  fi
}

# If Firefox is already running: open URL (typically new tab), pull Firefox to this workspace and focus.
# If not running: same as open_in_firefox (new window + Hypr poll for new client).
neko_focus_or_open_firefox_url() {
  local url="$1"
  [[ -z "$url" ]] && return 0
  if ! command -v firefox >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
    return 0
  fi
  if ! command -v hyprctl >/dev/null 2>&1; then
    if pgrep -x firefox >/dev/null 2>&1; then
      firefox "$url" >/dev/null 2>&1 &
    else
      firefox --new-window "$url" >/dev/null 2>&1 &
    fi
    return 0
  fi

  local wid before_file had_ff addr
  wid="$(neko_hypr_active_workspace_id)"
  before_file="$(mktemp)"
  neko_hypr_addrs_class_substr firefox >"$before_file"
  had_ff=0
  [[ -s "$before_file" ]] && had_ff=1

  if [[ "$had_ff" -eq 1 ]]; then
    firefox "$url" >/dev/null 2>&1 &
    if [[ -n "${NEKO_FF_HYPR_WAIT:-}" ]]; then
      sleep "$NEKO_FF_HYPR_WAIT"
    else
      sleep 0.2
    fi
    if [[ -n "$wid" ]]; then
      addr="$(neko_hypr_focused_firefox_address)"
      [[ -z "$addr" ]] && addr="$(neko_hypr_activewindow_firefox_address)"
      [[ -z "$addr" ]] && addr="$(neko_hypr_addrs_class_substr firefox | tail -n1)"
      [[ -n "$addr" ]] && neko_hypr_move_and_focus_addr "$wid" "$addr"
    fi
    rm -f "$before_file"
    return 0
  fi

  rm -f "$before_file"
  open_in_firefox "$url"
}
# Prefer Flatpak Discord (com.discordapp.Discord), then a `discord` binary on PATH.
neko_discord_try_launch() {
  if command -v flatpak >/dev/null 2>&1 && flatpak info com.discordapp.Discord >/dev/null 2>&1; then
    flatpak run com.discordapp.Discord >/dev/null 2>&1 &
    return 0
  fi
  if command -v discord >/dev/null 2>&1; then
    discord >/dev/null 2>&1 &
    return 0
  fi
  return 1
}

launch_discord_general() {
  local wid before_file
  wid=""
  if command -v hyprctl >/dev/null 2>&1; then
    wid="$(neko_hypr_active_workspace_id)"
  fi
  if neko_discord_try_launch; then
    before_file=""
    if [[ -n "$wid" ]]; then
      before_file="$(mktemp)"
      neko_hypr_addrs_class_substr discord >"$before_file"
    fi
    if [[ -n "$wid" ]] && [[ -n "$before_file" ]]; then
      neko_hypr_poll_move_new_matching "$wid" discord "$before_file" || true
      rm -f "$before_file"
    fi
    return 0
  fi
  open_in_firefox "https://discord.com/app"
}

# Start Slack desktop if possible. Optional \$1 = workspace URL to pass on cold start (Flatpak/native).
neko_slack_try_launch() {
  local start_url="${1:-}"
  if command -v slack >/dev/null 2>&1; then
    if [[ -n "$start_url" ]]; then
      slack "$start_url" >/dev/null 2>&1 &
    else
      slack >/dev/null 2>&1 &
    fi
    return 0
  fi
  if command -v flatpak >/dev/null 2>&1; then
    if flatpak info com.slack.Slack >/dev/null 2>&1; then
      if [[ -n "$start_url" ]]; then
        flatpak run com.slack.Slack "$start_url" >/dev/null 2>&1 &
      else
        flatpak run com.slack.Slack >/dev/null 2>&1 &
      fi
      return 0
    fi
  fi
  return 1
}

# Slack switches teams more reliably when opening …/messages than the bare workspace root.
neko_slack_messages_url() {
  local u="${1%/}"
  [[ -z "$u" ]] && return 0
  if [[ "$u" =~ ^https?://[a-zA-Z0-9.-]+\.slack\.com$ ]]; then
    printf '%s/messages\n' "$u"
    return 0
  fi
  printf '%s\n' "$u"
}

# Tell the running (or new) Slack app to open this workspace — Flatpak/native URL argv first, then xdg-open.
neko_slack_open_workspace_url() {
  local url="$1"
  [[ -z "$url" ]] && return 0
  local msg
  msg="$(neko_slack_messages_url "$url")"
  if command -v flatpak >/dev/null 2>&1 && flatpak info com.slack.Slack >/dev/null 2>&1; then
    flatpak run com.slack.Slack "$msg" >/dev/null 2>&1 &
    return 0
  fi
  if command -v slack >/dev/null 2>&1; then
    slack "$msg" >/dev/null 2>&1 &
    return 0
  fi
  xdg-open "$msg" >/dev/null 2>&1 || true
}

# Turn a hint into https://….slack.com — empty in → empty out; full URL → unchanged; subdomain → https://sub.slack.com
neko_slack_normalize_workspace_url() {
  local h="$1"
  [[ -z "$h" ]] && return 0
  if [[ "$h" =~ ^https?:// ]]; then
    printf '%s\n' "$h"
    return 0
  fi
  printf '%s\n' "https://${h}.slack.com"
}

# Launch Slack, Hyprland-pull every Slack window onto the *current* workspace, then switch Slack team via URL.
# Move-first avoids focus jumping to Slack's old workspace; Flatpak `com.slack.Slack <url>` switches the running client.
# \$1 = workspace hint: empty (any Slack), subdomain (nekologic), or full https://….slack.com
launch_slack_general() {
  local hint="${1:-}"
  local wid fb norm="" _try slack_addrs_file act_url
  fb="${NEKO_SLACK_FALLBACK_URL:-https://slack.com/signin}"
  [[ -n "$hint" ]] && norm="$(neko_slack_normalize_workspace_url "$hint")"
  [[ -n "$norm" ]] && fb="$norm"
  act_url=""
  [[ -n "$norm" ]] && act_url="$(neko_slack_messages_url "$norm")"

  if ! command -v hyprctl >/dev/null 2>&1; then
    if ! neko_slack_try_launch "$act_url"; then
      open_in_firefox "$fb"
    else
      [[ -n "$act_url" ]] && neko_slack_open_workspace_url "$norm"
    fi
    return 0
  fi

  wid="$(neko_hypr_active_workspace_id)"
  [[ -z "$wid" ]] && return 0

  if ! neko_slack_try_launch "$act_url"; then
    open_in_firefox "$fb"
    return 0
  fi

  # Wait for Slack OS windows, pull them here *before* team switch so focus does not jump to the old workspace.
  slack_addrs_file="$(mktemp)"
  for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
    sleep 0.1
    neko_hypr_addrs_class_substr slack >"$slack_addrs_file"
    if [[ -s "$slack_addrs_file" ]]; then
      neko_hypr_move_addrs_to_workspace "$wid" 0 <"$slack_addrs_file"
      break
    fi
  done
  rm -f "$slack_addrs_file"

  if [[ -n "$norm" ]]; then
    sleep 0.12
    neko_slack_open_workspace_url "$norm"
    sleep 0.22
    # Second nudge: some builds only switch team after a second open.
    neko_slack_open_workspace_url "$norm"
    sleep 0.18
  else
    sleep 0.15
  fi

  neko_hypr_addrs_class_substr slack | neko_hypr_move_addrs_to_workspace "$wid" 1
}

# Dispatch action specs for contextual [ButtonId] pills (focus-or-open for web URLs).
neko_dispatch_flow_button_spec() {
  local spec="$1"
  [[ -z "$spec" ]] && return 0
  case "$spec" in
    multi:*)
      local rest raw item
      rest="${spec#multi:}"
      while IFS= read -r raw || [[ -n "$raw" ]]; do
        [[ -z "$raw" ]] && continue
        item="$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -n "$item" ]] && neko_dispatch_flow_button_spec "$item"
      done <<< "$(echo "$rest" | tr ',' '\n')"
      ;;
    firefox:*)
      neko_focus_or_open_firefox_url "${spec#firefox:}"
      ;;
    discord)
      launch_discord_general
      ;;
    slack:*)
      launch_slack_general "${spec#slack:}"
      ;;
    slack)
      launch_slack_general "${NEKO_SLACK_DEFAULT_WS:-}"
      ;;
    shell:*)
      bash -c "${spec#shell:}"
      ;;
    http://*|https://*)
      neko_focus_or_open_firefox_url "$spec"
      ;;
    *)
      echo "neko: unknown flow button action: $spec" >&2
      ;;
  esac
}
