from pathlib import Path
import re
import shutil
import sys


root = Path(sys.argv[1])
target = root / "Programs-sfizz"
shutil.copytree(root / "Programs", target)

# sfizz lets a later silent region steal its sounding sister's voice.
# Keep each choke block intact, but start its voices before the samples.
pattern = re.compile(
    r"(<master>\s+ampeg_release=\$HH_MUTE_TIME\b.*?)"
    r'(<master>\s+note_polyphony=0\s+#include "[^"]*hh_silences[^"]*"\s*)',
    re.DOTALL,
)
changed = 0
for path in (target / "mappings").glob("*.sfz"):
    original = path.read_text()
    if "hh_silences" not in original:
        continue
    reordered, count = pattern.subn(r"\2\1", original)
    if count != 1:
        raise ValueError(f"Cannot identify the hi-hat choke block in {path}")
    path.write_text(reordered)
    changed += 1

if not changed:
    raise ValueError("No hi-hat choke blocks found")
