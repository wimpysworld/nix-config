"""Framed JSON client for the Wayfire IPC socket.

Wayfire frames IPC JSON with a four byte little-endian length prefix
in both directions.  Every Wayfire method name used by the lan-mouse
tooling lives in METHODS below, so an upstream rename is a single
edit.
"""
import glob
import json
import os
import socket
import struct
import sys

# Friendly aliases for the Wayfire IPC methods.  The stipc plugin is
# unstable, so nothing outside this table names a method directly.
METHODS = {
    "cursor": "window-rules/get_cursor_position",
    "outputs": "window-rules/list-outputs",
    "move-cursor": "stipc/move_cursor",
}


def find_socket():
    path = os.environ.get("WAYFIRE_SOCKET")
    if path:
        return path
    # The default socket path moved between Wayfire releases, so try
    # the runtime directory first and fall back to /tmp.
    patterns = (
        "/run/user/%d/wayfire-*.socket" % os.getuid(),
        "/tmp/wayfire-*.socket",
    )
    for pattern in patterns:
        matches = sorted(glob.glob(pattern), key=os.path.getmtime)
        if matches:
            return matches[-1]
    sys.exit("lan-mouse-wayfire-ipc: no Wayfire IPC socket found")


def read_exact(sock, count):
    data = b""
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            sys.exit("lan-mouse-wayfire-ipc: connection closed early")
        data += chunk
    return data


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: lan-mouse-wayfire-ipc <method> [json]")
    method = METHODS.get(sys.argv[1], sys.argv[1])
    data = json.loads(sys.argv[2]) if len(sys.argv) == 3 else {}
    request = json.dumps({"method": method, "data": data}).encode()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(find_socket())
        sock.sendall(struct.pack("<I", len(request)) + request)
        (length,) = struct.unpack("<I", read_exact(sock, 4))
        print(read_exact(sock, length).decode())


main()
