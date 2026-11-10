"""The package install phase checks the filter bypass and preserves upstream files."""

import re
import shutil
import sys
import zipfile
from pathlib import Path

archive, root = sys.argv[1:]
root = Path(root)
originals = root / "Programs"
adapted = root / "Programs-sfizz"
shutil.copytree(originals, adapted)

removed_line = re.compile(
    rb'(?:#include "controls/filter\.sfz"|label_cc(?:9[0-5]|113)=[^\r\n]*)\r?\n?'
)

for program in adapted.glob("*.sfz"):
    source = program.read_bytes()
    assert b'#include "controls/filter.sfz"' in source, program
    program.write_bytes(
        b"".join(line for line in source.splitlines(keepends=True) if not removed_line.fullmatch(line))
    )

with zipfile.ZipFile(archive) as upstream:
    for entry in upstream.namelist():
        if entry.startswith("Programs/") and not entry.endswith("/"):
            assert (root / entry).read_bytes() == upstream.read(entry), entry

assert {p.relative_to(originals) for p in originals.rglob("*")} == {
    p.relative_to(adapted) for p in adapted.rglob("*")
}
for original in originals.rglob("*"):
    if not original.is_file():
        continue
    relative = original.relative_to(originals)
    copy = adapted / relative
    if original.parent != originals:
        assert original.read_bytes() == copy.read_bytes(), relative
        continue
    retained = [line for line in original.read_bytes().splitlines() if not removed_line.fullmatch(line)]
    assert copy.read_bytes().splitlines() == retained, relative
    assert b'#include "controls/filter.sfz"' not in copy.read_bytes(), relative
