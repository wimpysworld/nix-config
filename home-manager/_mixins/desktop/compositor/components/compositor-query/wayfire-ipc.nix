# The Wayfire IPC client shared by compositor-query, lan-mouse-warp and
# lan-mouse-handoff. It is a stdlib-only Python programme because the
# protocol frames JSON with a four byte little-endian length prefix,
# which shell cannot do cleanly.
pkgs: pkgs.writers.writePython3Bin "compositor-wayfire-ipc" { } (builtins.readFile ./wayfire-ipc.py)
