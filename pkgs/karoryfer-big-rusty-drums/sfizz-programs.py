# The package installCheckPhase checks the metadata-only compatibility copy.
from pathlib import Path
import re
import shutil
import sys


mode, directory = sys.argv[1:]
root = Path(directory)
original = root / "Programs"
compatible = root / "Programs-sfizz"
full = Path("01-full.sfz")
label = re.compile(rb"^label_cc\d+=[^\r\n]*(?:\r?\n|$)", re.MULTILINE)

if mode == "create":
    shutil.copytree(original, compatible)
    program = compatible / full
    # sfizz 1.2.3 LV2 overflows its description buffer with the full kit's labels.
    program.write_bytes(label.sub(b"", program.read_bytes()))
elif mode == "check":
    source_files = {path.relative_to(original) for path in original.rglob("*")}
    copied_files = {path.relative_to(compatible) for path in compatible.rglob("*")}
    assert source_files == copied_files, "The compatibility tree must mirror Programs"
    removed = 0
    for relative in sorted(source_files):
        source = original / relative
        target = compatible / relative
        assert not target.is_symlink(), target
        if source.is_dir():
            assert target.is_dir(), target
            continue
        expected = source.read_bytes()
        if relative == full:
            lines = expected.splitlines(keepends=True)
            labels = [line for line in lines if label.fullmatch(line)]
            removed = len(labels)
            expected = b"".join(line for line in lines if not label.fullmatch(line))
        assert target.read_bytes() == expected, f"Unexpected SFZ change: {relative}"
    assert removed > 0, "The full kit must contain controller labels"
    assert not re.search(rb"\blabel_cc\d+\s*=", (compatible / full).read_bytes())
    print(f"Verified metadata-only compatibility copy: {removed} labels omitted")
else:
    raise ValueError(f"Unknown mode: {mode}")
