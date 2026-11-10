import base64
from pathlib import Path
import re
import shutil
import struct
import sys


out = Path(sys.argv[1])
data = out / "share/tchackpoum-ludwig-black-cortex"
resources = out / "share/reaper"
namespace = "Tchackpoum/LudwigBlackCortex"
effects = resources / "Effects" / namespace
shutil.copytree(data / "ReaperDrummer JSFX", effects)
shutil.copytree(
    data / "ReaperDrummer MIDINoteNames", resources / "MIDINoteNames/Tchackpoum"
)
templates = resources / "TrackTemplates/Tchackpoum"
templates.mkdir(parents=True)


def adapt_js(match):
    name = match[2].strip('"')
    if name == "utility/volume_pan_sample_accurate_auto":
        return match[0]
    name = name.rsplit("/", 1)[-1]
    if not (effects / name).is_file():
        raise ValueError(f"Missing JSFX: {name}")
    return f'{match[1]}"{namespace}/{name}"'


def encode(data, indent):
    return "".join(
        indent + base64.b64encode(data[i : i + 96]).decode() + "\n"
        for i in range(0, len(data), 96)
    )


def adapt_vst(match):
    indent, declaration, body = match.groups()
    plugin = re.search(r'" (\w+\.dll) ', declaration)[1]
    if plugin not in {
        "reasamplomatic.dll",
        "reaeq.dll",
        "reacomp.dll",
        "readelay.dll",
        "reaverb.dll",
    }:
        raise ValueError(f"Unsupported plug-in: {plugin}")
    declaration = declaration.replace(plugin, plugin.replace(".dll", ".vst.so"))
    if plugin == "reasamplomatic.dll":
        blob = b"".join(
            base64.b64decode(line.strip(), validate=True) for line in body.splitlines()
        )
        identifier, magic, inputs, outputs = struct.unpack_from("<4I", blob)
        if identifier != 1920167789 or magic != 0xFEED5EEE or inputs != 0:
            raise ValueError("Unexpected ReaSamplOmatic5000 header")
        # The host header stores output pin maps before the plug-in state length.
        size_offset = 16 + 8 * outputs
        state_offset = size_offset + 12
        size = struct.unpack_from("<I", blob, size_offset)[0]
        header = bytearray(blob[:state_offset])
        state = blob[state_offset : state_offset + size]
        trailer = blob[state_offset + size :]
        paths, marker, parameters = state.partition(
            b">0 YOU NEED A NEWER REASAMPLOMATIC, HIT LEAVE OFFLINE!\0"
        )
        if not marker or not parameters or trailer != b"\0Program 1\0\x10\0\0\0":
            raise ValueError("Unexpected ReaSamplOmatic5000 state")
        samples = []
        for original in paths.split(b"|"):
            sample = data / "samples" / original.decode().rsplit("\\", 1)[-1]
            if not sample.is_file() or sample.suffix.lower() != ".wav":
                raise ValueError(f"Missing sample: {sample}")
            samples.append(str(sample).encode())
        state = b"|".join(samples) + marker + parameters
        struct.pack_into("<I", header, size_offset, len(state))
        body = "".join(encode(part, indent + "  ") for part in (header, state, trailer))
    return f"{indent}<VST {declaration}\n{body}{indent}>"


for source in sorted((data / "ReaperDrummer TrackTemplate").glob("*.RTrackTemplate")):
    original = source.read_text()
    adapted = re.sub(r'(<JS )("[^"]+"|\S+)', adapt_js, original)
    adapted, count = re.subn(
        r"^([ \t]*)<VST (.*?)\n(.*?)^\1>",
        adapt_vst,
        adapted,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not count or ".dll" in adapted:
        raise ValueError(f"Incomplete template adaptation: {source.name}")
    (templates / source.name).write_text(adapted)
    print(f"Adapted {source.name}: {count} native plug-in instances")
