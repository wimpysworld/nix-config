"""Generate the picker catalogue from Unicode and explicit annotation relationships."""

import argparse
import hashlib
import json
import re
import tarfile
from pathlib import Path

TONES = ("light", "medium-light", "medium", "medium-dark", "dark")
ROW = re.compile(
    r"^([0-9A-F ]+)\s*;\s*([a-z-]+)\s*#\s*(\S+)\s+E([0-9.]+)\s+(.+)$"
)


def codepoint_id(emoji):
    return "-".join(f"{ord(character):04X}" for character in emoji)


def parse_catalogue(text):
    catalogue = {}
    group = subgroup = version = None
    for line in text.splitlines():
        if line.startswith("# Version: "):
            version = line.removeprefix("# Version: ")
        elif line.startswith("# group: "):
            group = line.removeprefix("# group: ")
            subgroup = None
        elif line.startswith("# subgroup: "):
            subgroup = line.removeprefix("# subgroup: ")
        elif line.strip() and not line.startswith("#"):
            match = ROW.fullmatch(line)
            if not match:
                raise ValueError(f"Malformed Unicode row: {line}")
            points, status, emoji, emoji_version, name = match.groups()
            if status not in {
                "fully-qualified", "minimally-qualified", "unqualified", "component"
            }:
                raise ValueError(f"Unknown qualification: {status}")
            if status != "fully-qualified":
                continue
            sequence = "".join(chr(int(point, 16)) for point in points.split())
            if sequence != emoji or not group or not subgroup or emoji in catalogue:
                raise ValueError(f"Invalid or duplicate Unicode sequence: {points}")
            catalogue[emoji] = {
                "id": codepoint_id(emoji),
                "emoji": emoji,
                "name": name,
                "group": group,
                "subgroup": subgroup,
                "emojiVersion": emoji_version,
            }
    if not version or not catalogue:
        raise ValueError("Unicode version or fully-qualified catalogue is absent")
    return version, catalogue


def normalise_keyword(value):
    if not isinstance(value, str):
        raise ValueError("Keywords must be strings")
    return " ".join(value.replace("_", " ").split()).casefold()


def skin_tones(row):
    tone = row.get("tone")
    tones = tone if isinstance(tone, list) else [tone]
    if not tones or any(type(value) is not int or value not in range(1, 6) for value in tones):
        raise ValueError(f"Invalid skin tone: {tone}")
    actual = [ord(character) - 0x1F3FA for character in row["emoji"]
              if 0x1F3FB <= ord(character) <= 0x1F3FF]
    if not actual or (tones != actual and not (len(tones) == 1 and set(actual) == set(tones))):
        raise ValueError(f"Skin tone does not match sequence: {row['emoji']}")
    return [TONES[value - 1] for value in actual]


def generate(catalogue, annotations, synonyms, overrides):
    indexed = {}
    parents = {}
    tones = {}

    def visit(row, parent=None):
        emoji = row["emoji"]
        if emoji in catalogue:
            if emoji in indexed:
                raise ValueError(f"Duplicate annotation: {emoji}")
            indexed[emoji] = row
            if parent is not None:
                if parent not in catalogue:
                    raise ValueError(f"Skin parent is absent from Unicode: {parent}")
                parents[emoji] = parent
                tones[emoji] = skin_tones(row)
        for child in row.get("skins", []):
            visit(child, parent if parent is not None else emoji)

    for row in annotations:
        visit(row)
    if catalogue.keys() - indexed.keys():
        raise ValueError("Annotations do not cover the Unicode catalogue")
    bases = catalogue.keys() - parents.keys()
    if overrides.keys() - bases:
        raise ValueError("Keyword overrides must refer to accepted base emoji")
    variants = {emoji: [] for emoji in bases}
    for emoji, entry in catalogue.items():
        if emoji in parents:
            variants[parents[emoji]].append({**entry, "tones": tones[emoji]})

    records = []
    for emoji, entry in catalogue.items():
        if emoji in parents:
            continue
        if any(0x1F3FB <= ord(character) <= 0x1F3FF for character in emoji):
            raise ValueError(f"Skin variant lacks an explicit parent: {emoji}")
        children = variants[emoji]
        multi_person = any(len(child["tones"]) > 1 for child in children)
        default_only = multi_person or entry["name"] == "family" or entry["name"].startswith("family:")
        skin_map = {}
        if not default_only:
            for child in children:
                tone = child["tones"][0]
                if tone in skin_map:
                    raise ValueError(f"Ambiguous skin tone mapping: {emoji}, {tone}")
                skin_map[tone] = child["emoji"]
        override = overrides.get(emoji, {})
        if override.keys() - {"add", "remove"}:
            raise ValueError(f"Unknown keyword override field: {emoji}")
        annotation = indexed[emoji]
        keywords = [entry["name"], annotation["label"]]
        keywords += annotation.get("tags", []) + synonyms.get(emoji, []) + override.get("add", [])
        removed = {normalise_keyword(value) for value in override.get("remove", [])}
        keywords = list(dict.fromkeys(normalise_keyword(value) for value in keywords))
        records.append({
            **entry,
            "keywords": [value for value in keywords if value and value not in removed],
            "skinTones": skin_map,
            "tonePolicy": "default" if default_only else "single",
            "variants": children,
        })
    return records


def archive_file(path, name):
    with tarfile.open(path, "r:gz") as archive:
        member = archive.getmember(f"package/{name}")
        if not member.isfile():
            raise ValueError(f"Archive member is not a regular file: {name}")
        stream = archive.extractfile(member)
        if stream is None:
            raise ValueError(f"Archive member has no content: {name}")
        with stream:
            return stream.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("unicode", "emojibase", "emojilib", "unicode-license", "sources", "overrides", "output"):
        parser.add_argument(f"--{option}", type=Path, required=True)
    args = parser.parse_args()
    sources = json.loads(args.sources.read_text())
    version, catalogue = parse_catalogue(args.unicode.read_text(encoding="utf-8"))
    if version != sources["unicode"]["version"]:
        raise ValueError("Unicode version does not match source metadata")
    for key in ("emojibase", "emojilib"):
        package = json.loads(archive_file(getattr(args, key), "package.json"))
        if package["version"] != sources[key]["version"]:
            raise ValueError(f"Package version does not match source metadata: {key}")
    sources["localOverrides"] = {
        "file": "keyword-overrides.json",
        "sha256": hashlib.sha256(args.overrides.read_bytes()).hexdigest(),
    }
    records = generate(
        catalogue,
        json.loads(archive_file(args.emojibase, "en/data.json")),
        json.loads(archive_file(args.emojilib, "dist/emoji-en-US.json")),
        json.loads(args.overrides.read_text(encoding="utf-8")),
    )
    args.output.mkdir(parents=True, exist_ok=True)
    master = {"schemaVersion": 1, "sources": sources, "emojis": records}
    (args.output / "master.json").write_text(
        json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    licenses = args.output / "licenses"
    licenses.mkdir(exist_ok=True)
    for key in ("emojibase", "emojilib"):
        (licenses / f"{key}-MIT.txt").write_bytes(archive_file(getattr(args, key), "LICENSE"))
    (licenses / "Unicode-3.0.txt").write_bytes(args.unicode_license.read_bytes())
    print(f"Generated {len(records)} base records covering {len(catalogue)} Unicode sequences")


if __name__ == "__main__":
    main()
