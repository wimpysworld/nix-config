import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SCHEMA_VERSION = 2
PROJECTION_VERSION = 6
TONES = ("yellow", "light", "medium-light", "medium", "medium-dark", "dark")
ROOT_ACTIONS = {
    0: ("new", "\U000f0e66 New"),
    1: ("browse", "\U000f12e3 Browse"),
    2: ("settings", "\U000f0493 Settings"),
}
BACK = object()
BACK_ROW = ("\U000f17b3 Back", "Back")


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as stream:
            temporary = Path(stream.name)
            stream.write(text)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def xdg_path(variable, fallback):
    return Path(os.environ.get(variable) or Path.home() / fallback) / "fuzzel-emoji"


def clean(text):
    return re.sub(r"[\x00-\x1f\x7f-\x9f\u2028\u2029]", " ", text)


def valid_glyph(text):
    return (
        bool(text)
        and not text.startswith("-")
        and all(not char.isspace() and clean(char) == char for char in text)
    )


def parse_projection(text):
    rows = tuple(tuple(line.split("\t")) for line in text.splitlines())
    if not rows or any(
        len(row) != 7
        or not all(row)
        or not valid_glyph(row[2])
        or not re.fullmatch(r"[0-9]+\.[0-9]+", row[6])
        or any(clean(field) != field for field in row)
        for row in rows
    ):
        raise ValueError("Invalid emoji projection")
    if len({row[5] for row in rows}) != len(rows):
        raise ValueError("Duplicate emoji IDs")
    return rows


def projection(master, tone):
    identity = json.dumps(
        [str(master.resolve()), SCHEMA_VERSION, PROJECTION_VERSION, tone]
    )
    key = hashlib.sha256(identity.encode()).hexdigest()
    cache = xdg_path("XDG_CACHE_HOME", ".cache") / f"{key}.tsv"
    try:
        return parse_projection(cache.read_text(encoding="utf-8"))
    except (FileNotFoundError, UnicodeError, ValueError):
        pass
    data = json.loads(master.read_text(encoding="utf-8"))
    if data["schemaVersion"] != SCHEMA_VERSION:
        raise ValueError("Unsupported emoji schema")
    lines = []
    for entry in data["emojis"]:
        glyph = entry["skinTones"].get(tone, entry["emoji"])
        if not valid_glyph(glyph):
            raise ValueError("Invalid emoji glyph")
        label = clean(f"{glyph} {entry['displayName']}")
        search = (
            clean(f"{label} · {' '.join(entry['searchKeywords'])}")
            if entry["searchKeywords"]
            else label
        )
        lines.append(
            "\t".join(
                [
                    label,
                    search,
                    glyph,
                    clean(entry["group"]),
                    clean(entry["subgroup"]),
                    entry["id"],
                    entry["emojiVersion"],
                ]
            )
        )
    text = "\n".join(lines) + "\n"
    rows = parse_projection(text)
    atomic_write(cache, text)
    return rows


def choose(rows, ordered=False, long_rows=False):
    result = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--index",
            "--only-match",
            *(["--no-sort"] if ordered else []),
            "--match-mode=exact",
            *(["--with-nth=2"] if long_rows else ["--with-nth=1", "--match-nth=2"]),
            "--width=48",
            "--prompt=󰞅 ",
            "--cache=/dev/null",
            f"--config={os.environ['FUZZEL_EMOJI_CONFIG']}",
        ],
        input="".join("\t".join(row) + "\n" for row in rows),
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        check=False,
    )
    # Fuzzel's dmenu cancel action exits with 2 (wayland.c, BIND_ACTION_CANCEL).
    if result.returncode == 2:
        return None
    if result.returncode != 0:
        raise ValueError(f"Fuzzel exited with status {result.returncode}")
    index = result.stdout.removesuffix("\n")
    if not re.fullmatch(r"0|[1-9][0-9]{0,8}", index):
        raise ValueError("Invalid Fuzzel index")
    number = int(index)
    if number >= len(rows):
        raise ValueError("Fuzzel index is out of range")
    return number


def choose_emoji(rows):
    selected = choose((BACK_ROW,) + rows, ordered=True)
    return BACK if selected is None or selected == 0 else rows[selected - 1][2]


def recent_rows(rows):
    def version(row):
        return tuple(map(int, row[6].split(".")))

    releases = sorted({version(row) for row in rows}, reverse=True)[:5]
    return tuple(
        (f"{row[6]} · {row[0]}", *row[1:])
        for row in sorted(rows, key=version, reverse=True)
        if version(row) in releases
    )


def browse(rows, from_root=False):
    groups = tuple(dict.fromkeys(row[3] for row in rows))
    group_rows = tuple((group, group) for group in groups)
    if from_root:
        group_rows = (BACK_ROW,) + group_rows
    while True:
        group_index = choose(group_rows, ordered=True)
        if group_index is None:
            return BACK if from_root else None
        if from_root and group_index == 0:
            return BACK
        group = groups[group_index - int(from_root)]
        subgroups = tuple(dict.fromkeys(row[4] for row in rows if row[3] == group))
        while True:
            subgroup_index = choose(
                (BACK_ROW,) + tuple((name, name) for name in subgroups), ordered=True
            )
            if subgroup_index is None or subgroup_index == 0:
                break
            subgroup = subgroups[subgroup_index - 1]
            entries = tuple(
                row for row in rows if row[3] == group and row[4] == subgroup
            )
            glyph = choose_emoji(entries)
            if glyph is not BACK:
                return glyph


def set_tone(state, tone="choose"):
    if tone == "choose":
        labels = (
            "👋 Default yellow",
            "👋🏻 Light",
            "👋🏼 Medium light",
            "👋🏽 Medium",
            "👋🏾 Medium dark",
            "👋🏿 Dark",
        )
        selected = choose(tuple((label, label) for label in labels), ordered=True)
        if selected is None:
            return None
        tone = TONES[selected]
    atomic_write(state, tone + "\n")
    return tone


def root_menu(master, rows, state):
    actions = tuple((label, label) for _, label in ROOT_ACTIONS.values())
    while True:
        selected = choose(actions + rows, long_rows=True)
        if selected is None:
            return None
        if selected not in ROOT_ACTIONS:
            return rows[selected - len(actions)][2]
        action = ROOT_ACTIONS[selected][0]
        if action == "settings":
            tone = set_tone(state)
            if tone is None:
                continue
            rows = projection(master, tone)
            continue
        if action == "new":
            glyph = choose_emoji(recent_rows(rows))
        else:
            glyph = browse(rows, from_root=True)
        if glyph is not BACK:
            return glyph


def main():
    parser = argparse.ArgumentParser(prog="fuzzel-emoji", add_help=False)
    parser.add_argument("master", type=Path, help=argparse.SUPPRESS)
    parser.add_argument(
        "-h", "--help", action="store_true", help="show this help message"
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--browse", action="store_true")
    modes.add_argument("--tone", nargs="?", const="choose", choices=("choose", *TONES))
    args = parser.parse_args()
    if args.help:
        parser.print_help(file=sys.stderr)
        return
    state = xdg_path("XDG_STATE_HOME", ".local/state") / "tone"
    if args.tone is not None:
        set_tone(state, args.tone)
        return
    try:
        tone = state.read_text(encoding="utf-8").strip()
    except (FileNotFoundError, UnicodeError):
        tone = "yellow"
    if tone not in TONES:
        tone = "yellow"
    # Keep the snapshot until Settings changes the tone, regardless of other picker processes.
    rows = projection(args.master, tone)
    if args.browse:
        glyph = browse(rows)
    else:
        glyph = root_menu(args.master, rows, state)
    if glyph is not None:
        print(glyph)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"fuzzel-emoji: {error}", file=sys.stderr)
        sys.exit(1)
