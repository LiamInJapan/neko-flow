# Repository layout — where is the implementation?

Everything shippable lives in this repo. **Your private workflow never belongs here** — only `config/*.example` and demo documents.

```
neko-flow/
├── lib/                    ← CORE IMPLEMENTATION (bash + python)
│   ├── neko_flow_doc_parse.py   Parser: flow_modes.txt → JSON meta for widget
│   ├── neko_flow_paths.sh       Config/lib path resolution
│   ├── neko_flow_actions.sh     Hyprland + Firefox + Slack launch helpers
│   ├── neko_flow_options.sh     Substate list helpers (used by cycle scripts)
│   ├── cycle_mode.sh            Super+Alt+Left/Right
│   ├── cycle_option.sh            Super+Alt+Up/Down
│   ├── execute_flow_option.sh   Super+Alt+Return (toggle + Sublime note)
│   ├── execute_flow_button.sh   [ButtonId] pill clicks
│   ├── set_mode.sh / set_option.sh
│   └── open_flow_notes.sh
│
├── quickshell/             ← UI (copy into your Quickshell tree)
│   ├── FlowWidget.qml           Desktop widget
│   └── ModeIndicator.qml        Bar mode pill
│
├── config/                 ← PUBLIC TEMPLATES ONLY (*.example)
│   ├── flow_modes.txt.example
│   ├── flow_button_actions.sh.example
│   ├── flow_launch_overrides.sh.example
│   └── documents/               Demo notes for fresh install
│
├── sublime/                ← Optional Sublime plugin
├── hypr/                   ← Keybind snippet
├── install.sh              ← Installs lib + bootstraps ~/.config/neko-flow
└── tests/
```

## Runtime (after `./install.sh`)

| Path | What |
|------|------|
| `~/.local/share/neko-flow/lib/` | Installed copy of `lib/` |
| `~/.local/bin/neko-flow-*` | CLI entrypoints |
| `~/.config/neko-flow/` | **Your private config** (gitignored on your machine) |

The widget reads **config** for state files and **lib** for scripts/parser.

## Data flow

```
flow_modes.txt  ──► neko_flow_doc_parse.py meta ──► FlowWidget.qml
       │                                              │
       └── [ButtonId] ──► flow_button_actions.sh ──► neko_flow_actions.sh
```

Private URLs and real modes live only in `~/.config/neko-flow/` (or `~/.config/neko/` if you migrated).
