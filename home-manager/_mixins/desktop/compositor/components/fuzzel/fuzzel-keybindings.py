import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

CATEGORY_ORDER = (
    "Application",
    "Menu",
    "Session",
    "Capture",
    "Audio",
    "Media",
    "Display",
    "Workspaces",
    "Windows",
    "Resize Windows",
)
CATEGORY_RANK = {category: rank for rank, category in enumerate(CATEGORY_ORDER)}
GROUP_GLYPHS = {
    "Application": "\U000f003b",
    "Menu": "\U000f035c",
    "Session": "\U000f11ef",
    "Capture": "\U000f13b4",
    "Audio": "\U000f057e",
    "Media": "\U000f127a",
    "Display": "\U000f00df",
    "Workspaces": "\U000f11d9",
    "Windows": "\U000f08c6",
    "Resize Windows": "\U000f01be",
}


def field(text):
    return "".join(char if char.isprintable() else " " for char in text)


def display_width(text):
    return sum(
        0
        if unicodedata.category(char) in ("Mn", "Me")
        else 2
        if unicodedata.east_asian_width(char) in ("W", "F")
        else 1
        for char in text
    )


def choose(rows, width, ordered=False):
    result = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--index",
            "--only-match",
            *(["--no-sort"] if ordered else []),
            "--match-mode=exact",
            "--with-nth=1",
            "--match-nth=2",
            f"--width={min(width, 120)}",
            "--prompt=󰌌 ",
            "--cache=/dev/null",
            f"--config={sys.argv[2]}",
        ],
        input="".join(rows),
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        check=False,
    )
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


def main():
    entries = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    entries.sort(
        key=lambda entry: (
            CATEGORY_RANK.get(entry["category"], len(CATEGORY_ORDER)),
            entry["category"],
        )
    )
    columns = [
        tuple(field(entry[name]) for name in ("keys", "description", "category"))
        for entry in entries
    ]
    key_width = max((display_width(keys) for keys, _, _ in columns), default=0)
    description_width = max(
        (display_width(description) for _, description, _ in columns), default=0
    )
    rows = []
    width = 56
    for entry, (keys, description, category) in zip(entries, columns, strict=True):
        label = "{}{}  {}{}  {}".format(
            keys,
            " " * (key_width - display_width(keys)),
            description,
            " " * (description_width - display_width(description)),
            category,
        )
        search = " ".join(
            [
                f"{keys}  {description}  {category}",
                *(field(word) for word in entry.get("keywords", [])),
            ]
        )
        rows.append(f"{label}\t{search}\n")
        width = max(width, display_width(label))
    if not rows:
        label = "No configured keyboard shortcuts"
        choose([f"{label}\t{label}\n"], width)
        return
    groups = tuple(dict.fromkeys(entry["category"] for entry in entries))
    back = "\U000f17b3 Back\tBack\n"
    group_rows = [back] + [
        f"{GROUP_GLYPHS[group] + ' ' if group in GROUP_GLYPHS else ''}"
        f"{field(group)}\t{field(group)}\n"
        for group in groups
    ]
    while True:
        selected = choose(["\U000f09f9 Browse\tBrowse\n"] + rows, width)
        if selected is None or selected != 0:
            return
        while True:
            selected = choose(group_rows, width, ordered=True)
            if selected is None or selected == 0:
                break
            group = groups[selected - 1]
            group_entries = [
                row
                for entry, row in zip(entries, rows, strict=True)
                if entry["category"] == group
            ]
            selected = choose([back] + group_entries, width, ordered=True)
            if selected is not None and selected != 0:
                return


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"fuzzel-keybindings: {error}", file=sys.stderr)
        sys.exit(1)
