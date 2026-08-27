# The Wayfire IPC helper shared by lan-mouse-warp and lan-mouse-handoff.
# It is a stdlib-only Python programme because the protocol frames JSON
# with a four byte little-endian length prefix, which shell cannot do
# cleanly.
pkgs:
pkgs.writers.writePython3Bin "lan-mouse-wayfire-ipc" { } (
  builtins.readFile ./lan-mouse-wayfire-ipc.py
)
