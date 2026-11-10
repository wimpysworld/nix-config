import os
from pathlib import Path
import stat
import sys
import tempfile


START = b"-- BEGIN nix-config REAPER MCP bridge"
END = b"-- END nix-config REAPER MCP bridge"
LOAD = b'pcall(dofile, reaper.GetResourcePath() .. "/Scripts/reaper_mcp_bridge.lua")'


def merge_startup(path):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f"Refusing to replace a startup symlink: {path}")
    exists = path.exists()
    original = path.read_bytes() if exists else b""
    lines = original.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip(b"\r\n") == START]
    ends = [i for i, line in enumerate(lines) if line.rstrip(b"\r\n") == END]
    if (starts or ends) and not (len(starts) == len(ends) == 1 and starts[0] < ends[0]):
        raise ValueError(f"Invalid managed startup block: {path}")
    newline = b"\r\n" if b"\r\n" in original else b"\n"
    block = newline.join([START, LOAD, END]) + newline
    if starts:
        updated = b"".join(lines[: starts[0]]) + block + b"".join(lines[ends[0] + 1 :])
    else:
        separator = newline if original and not original.endswith(b"\n") else b""
        updated = original + separator + block
    if updated == original:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if exists else 0o644
    if exists:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f"{path.name}.backup-", delete=False) as backup:
            backup.write(original)
            os.fchmod(backup.fileno(), mode)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(updated)
            output.flush()
            os.fchmod(output.fileno(), mode)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    merge_startup(sys.argv[1])
