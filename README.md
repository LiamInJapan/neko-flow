# Neko Flow

Text-file-driven **focus modes** for Hyprland + Quickshell: cycle modes and substates, mark what you're doing, open notes, launch apps via contextual buttons.

## What it does

- **Modes** (COMMS, WORK, CLEAN, …) defined in `flow_modes.txt`
- **Substates** per mode with optional `[ButtonId]` pills for one-click app opens
- **Super+Alt+ arrows** — cycle mode / substate
- **Super+Alt+Return** — toggle "executed" state + open mode note in Sublime
- **Flow widget** on the desktop + optional **mode pill** in the bar

## Requirements

- [Hyprland](https://hyprland.org/)
- [Quickshell](https://quickshell.outfoxxed.me/) (tested with illogical-impulse-style configs)
- Python 3.10+
- Optional: Firefox, Slack desktop, Sublime Text

## Quick install

```bash
git clone <your-repo-url> neko-flow
cd neko-flow
./install.sh
```

Then follow [docs/INTEGRATION.md](docs/INTEGRATION.md) for Hyprland keybinds and Quickshell widget copy.

## Configuration

| File | Purpose |
|------|---------|
| `~/.config/neko-flow/flow_modes.txt` | Modes, substates, `[ButtonId]` tags |
| `~/.config/neko-flow/flow_button_actions.sh` | Map button IDs → slack / firefox / shell actions |
| `~/.config/neko-flow/flow_launch_overrides.sh` | Private URLs, `NEKO_DOCUMENTS`, etc. |
| `~/Documents/<MODE>.md` | Per-mode notes (optional) |

See `config/*.example` for starters.

## CLI

After install, these land in `~/.local/bin/`:

| Command | Action |
|---------|--------|
| `neko-flow-cycle-mode` | prev/next mode |
| `neko-flow-cycle-option` | prev/next substate |
| `neko-flow-execute` | Super+Alt+Return handler |
| `neko-flow-button` | Contextual button dispatcher |
| `neko-flow-set-mode` | Jump to a mode |
| `neko-flow-open-notes` | Open mode note in Sublime |

## Development

```bash
./install.sh --dev --config-dir ~/.config/neko-flow
python3 -m unittest discover -s tests -v
```

## License

MIT — see [LICENSE](LICENSE).
