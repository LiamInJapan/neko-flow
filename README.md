# Neko Flow

Text-file-driven **focus modes** for Hyprland + Quickshell: cycle modes and substates, mark what you're doing, open notes, launch apps via contextual buttons.

## Where is the code?

**All implementation is in this repo** — see **[docs/LAYOUT.md](docs/LAYOUT.md)** for a map.

| You want… | Look here |
|-----------|-----------|
| Parser, scripts, app launch logic | **`lib/`** |
| Desktop widget UI | **`quickshell/`** |
| Public config templates | **`config/*.example`** |
| Demo notes for try-out install | **`config/documents/`** |

After `./install.sh`, `lib/` is copied to `~/.local/share/neko-flow/lib/`.  
Your **private** workflow stays in `~/.config/neko-flow/` (never committed to this repo).

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
git clone https://github.com/LiamInJapan/neko-flow.git
cd neko-flow
./install.sh
```

This creates `~/.config/neko-flow/` with **example modes, button map, and demo notes** — safe test data, not your real workflow.

Then follow [docs/INTEGRATION.md](docs/INTEGRATION.md) for Hyprland keybinds and Quickshell widget copy.

## Private configuration

These files are **gitignored** on your machine after install (see `config/gitignore`):

| File | Purpose |
|------|---------|
| `flow_modes.txt` | Your modes and substates |
| `flow_button_actions.sh` | Your button → URL/Slack mappings |
| `flow_launch_overrides.sh` | Private URLs, `NEKO_DOCUMENTS`, etc. |
| `current_mode`, `flow_executed.json`, … | Runtime state |

Only `config/*.example` and `config/documents/` ship in the public repo.

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

Open **`~/Development/neko-flow`** (or your clone) — you do **not** need your whole `~/.config` dotfiles repo.

```bash
./install.sh --dev --config-dir ~/.config/neko-flow
python3 -m unittest discover -s tests -v
```

## License

MIT — see [LICENSE](LICENSE).
