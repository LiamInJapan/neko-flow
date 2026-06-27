#!/usr/bin/env python3
"""
Neko Flow: substates live in NEKO_FLOW_CONFIG_DIR/flow_modes.txt ([MODE] blocks).
Loose notes per mode live in NEKO_DOCUMENTS/<MODE>.md (bullets only, no [SubStates]).

flow_modes.txt format:

  [COMMS]
  @DESC Short blurb for this mode (shown under the mode title)
  - Label - description
  - Label - description [ButtonId] [OtherButton]
  @TASKS Tasks

Contextual buttons (on substate line, stripped from label/description in the widget):
  [NekoConfidential]  [ContractBoard]  — wired in flow_button_actions.sh (+ flow_launch_overrides.sh URLs)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DEFAULT_OPTIONS: dict[str, list[str]] = {
    "WORK": ["Ship feature", "Deep work sprint", "Close one task"],
    "COMMS": [
        "Nekologic Main Comms",
        "Airbnb",
        "Gmail",
        "Ace Consulting",
        "LinkedIn Marketing Team",
        "Discord General",
    ],
    "CREATE": ["Draft concept", "Build prototype", "Polish output"],
    "CLEAN": [
        "Clean Mail",
        "Clean Notes",
        "Clean Desktop",
        "Clean Downloads",
        "Clean GDrive",
    ],
    "BIZDEV": ["Open NekoCRM Asana", "Open GlobalCRM"],
    "LEGAL": [
        "Overview",
        "TODO: Check contract dashboard",
        "Staff",
        "Clients",
        "General",
    ],
    "HR": ["1:1 prep", "Hiring notes", "People follow-ups"],
    "FINANCE": ["Check runway", "Review spend", "Invoice pass"],
    "ADMIN": ["Calendar cleanup", "Docs update", "Ops checklist"],
    "EXPLORE": ["Read + notes", "Test idea", "Skill reps"],
    "RECOVER": ["Walk break", "Water + stretch", "Low-effort reset"],
    "STUCK": ["Pick smallest next step", "Ask for help", "15-min timer"],
}

_RE_MODE_HEADER = re.compile(r"^\[([^\]]+)\]\s*$")
_RE_PIPE = re.compile(r"^-\s+(.+?)\s*\|\s*(.*)$")
_RE_PAREN = re.compile(r"^-\s+(.+?)\s+\(\s*(.*)\s*\)\s*$")
_RE_LABEL = re.compile(r"^-\s+(.+)$")
_RE_BUTTON = re.compile(r"\[([A-Za-z0-9_-]+)\]")
_RE_NOTE_BULLET = re.compile(r"^-\s+(.+)$")


def _parse_desc_text(line: str) -> str | None:
    """Parse @DESC / @desc / > description text from a trimmed line."""
    t = line.strip()
    if not t:
        return None
    u = t.upper()
    if u.startswith("@DESC"):
        rest = t[5:].lstrip(": ").strip()
        return rest or None
    if t.startswith(">"):
        rest = t[1:].strip()
        return rest or None
    return None


def _split_title_desc(rest: str) -> tuple[str, str]:
    """Split 'Title - description' from a header remainder."""
    text = rest.strip()
    if " - " in text:
        title, desc = text.split(" - ", 1)
        return title.strip(), desc.strip()
    return text, ""


def _extract_buttons(text: str) -> tuple[str, list[str]]:
    """Pull [ButtonId] tokens out of text; return cleaned remainder and button ids."""
    buttons = _RE_BUTTON.findall(text)
    cleaned = _RE_BUTTON.sub(" ", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip().strip(",").strip()
    return cleaned, buttons


def _parse_substate_line(raw: str) -> tuple[str, str, list[str]] | None:
    """Parse a substate line into (label, description, buttons).

    Formats:
      - Label
      - Label - description
      - Label [ButtonA] [ButtonB]
      - Label - description [ButtonA]
    Legacy ``| action`` suffixes on substate lines are ignored (use [ButtonId] instead).
    """
    label_part = ""

    m = _RE_PIPE.match(raw)
    if m:
        label_part = m.group(1).strip()
    else:
        m = _RE_PAREN.match(raw)
        if m:
            label_part = m.group(1).strip()
        else:
            m = _RE_LABEL.match(raw)
            if not m:
                return None
            label_part = m.group(1).strip()

    if not label_part:
        return None

    label_part, buttons_lead = _extract_buttons(label_part)
    label, desc = _split_title_desc(label_part)
    buttons = list(buttons_lead)
    if desc:
        desc, buttons_tail = _extract_buttons(desc)
        buttons.extend(buttons_tail)

    if not label:
        return None
    return label, desc, buttons


def _try_consume_indented_desc(lines: list[str], index: int) -> tuple[str | None, int]:
    """If the next line is an indented description, return (text, extra_lines_consumed)."""
    if index + 1 >= len(lines):
        return None, 0
    nraw = lines[index + 1]
    if not (nraw.startswith("  ") or nraw.startswith("\t")):
        return None, 0
    desc = _parse_desc_text(nraw.strip())
    if not desc:
        return None, 0
    return desc, 1


def _documents_root() -> Path:
    raw = os.environ.get("NEKO_DOCUMENTS")
    if raw and str(raw).strip():
        return Path(raw)
    return Path.home() / "Documents"


def resolve_flow_modes_path() -> Path:
    raw = os.environ.get("NEKO_FLOW_MODES")
    if raw and str(raw).strip():
        return Path(raw)
    config = os.environ.get("NEKO_FLOW_CONFIG_DIR")
    if config and str(config).strip():
        return Path(config) / "flow_modes.txt"
    legacy = Path.home() / ".config" / "neko-flow" / "flow_modes.txt"
    if legacy.is_file():
        return legacy
    return Path.home() / ".config" / "neko" / "flow_modes.txt"


def read_text(path: Path) -> str:
    try:
        if path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        pass
    return ""


def parse_flow_mode_order(text: str) -> list[str]:
    order: list[str] = []
    for line in text.splitlines():
        m = _RE_MODE_HEADER.match(line.strip())
        if m:
            order.append(m.group(1).upper())
    if order:
        return order
    # Legacy: one mode name per line (no [MODE] blocks).
    legacy: list[str] = []
    for line in text.splitlines():
        s = line.split("#", 1)[0].strip()
        if not s or s.startswith("["):
            continue
        legacy.append(s.upper())
    return legacy


def parse_flow_mode_sections(text: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    current: str | None = None
    buf: list[str] = []
    for line in text.splitlines():
        m = _RE_MODE_HEADER.match(line.strip())
        if m:
            if current is not None:
                sections[current] = "\n".join(buf)
            current = m.group(1).upper()
            buf = []
            continue
        if current is None:
            continue
        buf.append(line)
    if current is not None:
        sections[current] = "\n".join(buf)
    return sections


def substates_text_for_mode(mode: str) -> str:
    path = resolve_flow_modes_path()
    sections = parse_flow_mode_sections(read_text(path))
    block = sections.get(mode.upper(), "")
    if block.strip():
        return block
    # Legacy fallback: [SubStates] in ~/Documents/<MODE>.md
    return read_text(resolve_notes_path(mode))


def _overview_inside_mode_dir(d: Path, mu: str, ml: str) -> Path | None:
    for inner in (d / f"{mu}.md", d / f"{ml}.md", d / "overview.md", d / "README.md"):
        if inner.is_file():
            return inner
    return None


def resolve_notes_path(mode: str) -> Path:
    """Loose notes file for a mode (Sublime + widget Notes section)."""
    docs = _documents_root()
    mu = mode.upper()
    ml = mode.lower()

    for ext in (".md", ".txt", ".org"):
        for p in (docs / f"{mu}{ext}", docs / f"{ml}{ext}"):
            if p.is_file():
                return p

    for p in (docs / mu, docs / ml):
        if p.is_file():
            return p
        if p.is_dir():
            inner = _overview_inside_mode_dir(p, mu, ml)
            if inner is not None:
                return inner
            return p

    return docs / f"{mu}.md"


def resolve_doc_path(mode: str) -> Path:
    """Alias for notes path (execute_flow_option / Sublime)."""
    return resolve_notes_path(mode)


def strip_substates_block(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    in_block = False
    for line in lines:
        u = line.strip().upper()
        if u == "[SUBSTATES]":
            in_block = True
            continue
        if in_block:
            if u == "[/SUBSTATES]":
                in_block = False
            continue
        out.append(line)
    return "\n".join(out)


def parse_loose_notes(
    text: str,
    *,
    max_lines: int = 12,
    max_chars: int = 900,
) -> str:
    """Multi-line notes preview for the widget (skips markdown headings, keeps bullets)."""
    body = strip_substates_block(text)
    out_lines: list[str] = []
    non_empty = 0
    for line in body.splitlines():
        if line.startswith("\t") or line.startswith("    "):
            continue
        s = line.strip()
        if not s:
            if out_lines and out_lines[-1] != "":
                out_lines.append("")
            continue
        if s.startswith("#"):
            continue
        m = _RE_NOTE_BULLET.match(s)
        out_lines.append(m.group(1).strip() if m else s)
        non_empty += 1
        if non_empty >= max_lines:
            break
    while out_lines and out_lines[-1] == "":
        out_lines.pop()
    joined = "\n".join(out_lines)
    if len(joined) > max_chars:
        joined = joined[: max_chars - 1].rstrip() + "…"
    return joined


def parse_loose_notes_list(text: str, *, limit: int = 16) -> list[str]:
    """Legacy list form — non-empty lines only."""
    body = parse_loose_notes(text, max_lines=limit)
    return [ln for ln in body.split("\n") if ln.strip()]


def parse_substates_with_layout(text: str) -> tuple[list[tuple[str, str]], dict[str, object]] | None:
    lines = text.splitlines()
    start: int | None = None
    for i, line in enumerate(lines):
        if line.strip().upper() == "[SUBSTATES]":
            start = i + 1
            break
    parse_lines = lines[start:] if start is not None else lines

    out: list[tuple[str, str]] = []
    layout: dict[str, object] = {
        "routineTitle": None,
        "routineDescription": None,
        "tasksTitle": None,
        "tasksDescription": None,
        "notesTitle": None,
        "modeDescription": None,
        "optionDescriptions": {},
        "optionButtons": {},
        "inlineHeaders": [],
        "routineIndices": [],
        "tasksIndices": [],
    }
    current_group = "routine"
    option_descriptions: dict[int, str] = {}
    option_buttons: dict[int, list[str]] = {}

    i = 0
    while i < len(parse_lines):
        raw = parse_lines[i].rstrip("\n")
        s = raw.strip()
        if not s:
            if out and start is not None:
                break
            i += 1
            continue
        if s.upper() == "[/SUBSTATES]":
            break

        u = s.upper()
        if u.startswith("@DESC"):
            desc = _parse_desc_text(s)
            if desc:
                layout["modeDescription"] = desc
            i += 1
            continue
        if u.startswith("@ROUTINE "):
            title, desc = _split_title_desc(s[len("@ROUTINE ") :])
            layout["routineTitle"] = title or None
            if desc:
                layout["routineDescription"] = desc
            else:
                nd, extra = _try_consume_indented_desc(parse_lines, i)
                if nd:
                    layout["routineDescription"] = nd
                    i += extra
            current_group = "routine"
            i += 1
            continue
        if u.startswith("@TASKS "):
            title, desc = _split_title_desc(s[len("@TASKS ") :])
            layout["tasksTitle"] = title or None
            if desc:
                layout["tasksDescription"] = desc
            else:
                nd, extra = _try_consume_indented_desc(parse_lines, i)
                if nd:
                    layout["tasksDescription"] = nd
                    i += extra
            current_group = "tasks"
            i += 1
            continue
        if u.startswith("@NOTES "):
            layout["notesTitle"] = s[len("@NOTES ") :].strip()
            i += 1
            continue
        if u.startswith("@INLINE ") or u.startswith("@HEADER "):
            prefix = "@INLINE " if u.startswith("@INLINE ") else "@HEADER "
            title = s[len(prefix) :].strip()
            if title:
                layout["inlineHeaders"].append({"at": len(out), "title": title})
            i += 1
            continue

        label: str | None = None
        desc = ""
        buttons: list[str] = []
        parsed = _parse_substate_line(raw)
        if parsed:
            label, desc, buttons = parsed

        if label:
            out.append((label, ""))
            opt_idx = len(out) - 1
            if current_group == "routine":
                layout["routineIndices"].append(opt_idx)
            else:
                layout["tasksIndices"].append(opt_idx)
            if desc:
                option_descriptions[opt_idx] = desc
            else:
                nd, extra = _try_consume_indented_desc(parse_lines, i)
                if nd:
                    option_descriptions[opt_idx] = nd
                    i += extra
            if buttons:
                option_buttons[opt_idx] = buttons
        i += 1

    layout["optionDescriptions"] = option_descriptions
    layout["optionButtons"] = option_buttons

    if not out:
        return None
    return out, layout


def options_for_mode(mode: str, text: str) -> list[str]:
    parsed = parse_substates_with_layout(text)
    if parsed:
        sub, _layout = parsed
        labels = [a[0] for a in sub if a[0]]
        if labels:
            return labels
    return list(DEFAULT_OPTIONS.get(mode.upper(), DEFAULT_OPTIONS["WORK"]))


def cmd_modes() -> None:
    text = read_text(resolve_flow_modes_path())
    for mode in parse_flow_mode_order(text):
        print(mode)


def cmd_list(mode: str) -> None:
    text = substates_text_for_mode(mode)
    for opt in options_for_mode(mode, text):
        print(opt)


def cmd_defaults(mode: str) -> None:
    for opt in DEFAULT_OPTIONS.get(mode.upper(), DEFAULT_OPTIONS["WORK"]):
        if opt:
            print(opt)


def cmd_meta(mode: str) -> None:
    flow_path = resolve_flow_modes_path()
    sub_text = substates_text_for_mode(mode)
    notes_path = resolve_notes_path(mode)
    notes_text = read_text(notes_path)

    parsed = parse_substates_with_layout(sub_text)
    opts: list[str] = []
    layout: dict[str, object] | None = None
    if parsed:
        sub, layout = parsed
        opts = [a[0] for a in sub if a[0]]
    if not opts:
        opts = options_for_mode(mode, sub_text)

    routine_title = ""
    routine_description = ""
    tasks_title = ""
    tasks_description = ""
    notes_title = "Notes"
    mode_description = ""
    option_descriptions_out: dict[str, str] = {}
    option_buttons_out: dict[str, list[str]] = {}
    inline_headers: list[dict[str, object]] = []

    if layout is not None:
        if isinstance(layout.get("routineTitle"), str) and layout["routineTitle"].strip():
            routine_title = layout["routineTitle"].strip()
        if isinstance(layout.get("routineDescription"), str) and layout["routineDescription"].strip():
            routine_description = layout["routineDescription"].strip()
        if isinstance(layout.get("tasksTitle"), str) and layout["tasksTitle"].strip():
            tasks_title = layout["tasksTitle"].strip()
        if isinstance(layout.get("tasksDescription"), str) and layout["tasksDescription"].strip():
            tasks_description = layout["tasksDescription"].strip()
        if isinstance(layout.get("notesTitle"), str) and layout["notesTitle"].strip():
            notes_title = layout["notesTitle"].strip()
        if isinstance(layout.get("modeDescription"), str) and layout["modeDescription"].strip():
            mode_description = layout["modeDescription"].strip()

        raw_option_desc = layout.get("optionDescriptions")
        if isinstance(raw_option_desc, dict):
            for k, v in raw_option_desc.items():
                if isinstance(v, str) and v.strip():
                    option_descriptions_out[str(k)] = v.strip()

        raw_option_buttons = layout.get("optionButtons")
        if isinstance(raw_option_buttons, dict):
            for k, v in raw_option_buttons.items():
                if isinstance(v, list):
                    ids = [str(b).strip() for b in v if isinstance(b, str) and str(b).strip()]
                    if ids:
                        option_buttons_out[str(k)] = ids

        file_inline = layout.get("inlineHeaders")
        if isinstance(file_inline, list):
            for h in file_inline:
                if (
                    isinstance(h, dict)
                    and isinstance(h.get("at"), int)
                    and isinstance(h.get("title"), str)
                    and h["title"].strip()
                ):
                    inline_headers.append({"at": h["at"], "title": h["title"].strip()})

    routine_options: list[str] = []
    tasks_options: list[str] = []
    routine_global_indices: list[int] = []
    tasks_global_indices: list[int] = []

    if (
        layout is not None
        and isinstance(layout.get("routineIndices"), list)
        and isinstance(layout.get("tasksIndices"), list)
        and parsed is not None
    ):
        routine_indices = layout.get("routineIndices") or []
        tasks_indices = layout.get("tasksIndices") or []
        routine_set = set(i for i in routine_indices if isinstance(i, int))
        tasks_set = set(i for i in tasks_indices if isinstance(i, int))
        for i, (lab, _act) in enumerate(sub):
            if i in routine_set:
                routine_options.append(lab)
                routine_global_indices.append(i)
            if i in tasks_set:
                tasks_options.append(lab)
                tasks_global_indices.append(i)

    notes_body = parse_loose_notes(notes_text)

    layout_out: dict[str, object] = {
        "routineTitle": routine_title,
        "routineDescription": routine_description,
        "tasksTitle": tasks_title,
        "tasksDescription": tasks_description,
        "notesTitle": notes_title,
        "modeDescription": mode_description,
        "optionDescriptions": option_descriptions_out,
        "optionButtons": option_buttons_out,
        "notesBody": notes_body,
        "notesLines": parse_loose_notes_list(notes_text),
        "inlineHeaders": inline_headers,
        "routineOptions": routine_options,
        "tasksOptions": tasks_options,
        "routineGlobalIndices": routine_global_indices,
        "tasksGlobalIndices": tasks_global_indices,
    }
    print(
        json.dumps(
            {
                "mode": mode.upper(),
                "path": str(flow_path.resolve()),
                "notesPath": str(notes_path.resolve()),
                "options": opts,
                "layout": layout_out,
            },
            ensure_ascii=False,
        ),
        end="",
    )


def cmd_notes(mode: str) -> None:
    notes_path = resolve_notes_path(mode)
    notes_text = read_text(notes_path)
    print(
        json.dumps(
            {
                "mode": mode.upper(),
                "notesPath": str(notes_path.resolve()),
                "notesBody": parse_loose_notes(notes_text),
            },
            ensure_ascii=False,
        ),
        end="",
    )


def cmd_path(mode: str) -> None:
    print(str(resolve_notes_path(mode).resolve()), end="")


def main() -> None:
    if len(sys.argv) < 2:
        print(
            "usage: neko_flow_doc_parse.py {modes|list|defaults|meta|notes|path} [MODE] [OPTION]",
            file=sys.stderr,
        )
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == "modes":
        cmd_modes()
        return
    if len(sys.argv) < 3:
        print(
            "usage: neko_flow_doc_parse.py {list|defaults|meta|notes|path} MODE [OPTION]",
            file=sys.stderr,
        )
        sys.exit(2)
    mode = sys.argv[2]
    if cmd == "list":
        cmd_list(mode)
    elif cmd == "defaults":
        cmd_defaults(mode)
    elif cmd == "meta":
        cmd_meta(mode)
    elif cmd == "notes":
        cmd_notes(mode)
    elif cmd == "path":
        cmd_path(mode)
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
