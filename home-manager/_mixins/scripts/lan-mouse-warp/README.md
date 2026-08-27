# lan-mouse-warp

The receiver side of proportional cursor placement for
[lan-mouse](https://github.com/feschber/lan-mouse). See
`../lan-mouse-handoff/README.md` for why this tooling exists.

## Modes

- `lan-mouse-warp <left|right|top|bottom> <fraction>` warps the local
  cursor to the given fraction along the edge-most monitor for that
  entry edge, two logical pixels inside the edge. Invoked over SSH by
  the peer's `lan-mouse-handoff`, so it runs without any session
  environment and validates both arguments strictly.
- `lan-mouse-warp report <edge>` prints the current cursor's fraction
  along that edge's axis, clamped to the unit interval. `lan-mouse-hookd`
  on the peer uses it to mirror return crossings, because lan-mouse
  runs no hook on a return.
- `lan-mouse-warp serve` reads `warp <edge> <fraction>` and
  `report <edge>` lines from stdin in a loop. A warp line answers
  nothing, a report line answers one fraction line, an invalid line
  logs to stderr and the loop continues, and EOF ends the session.
  The peer's `lan-mouse-hookd` holds one serve session open over SSH
  per client, so a crossing costs one round trip and no process
  spawns. Compositor detection stays per-command, so a compositor
  restart does not wedge the server.

  serve is also a stateful watcher for return crossings, because the
  controlled machine knows about a return before anyone else. It
  follows the local daemon's IPC socket through a socat coproc, and a
  `DeviceEntered` event arms it with the entry edge. While armed it
  polls the cursor every 40 ms. A guard stays closed until the cursor
  moves more than 15 logical pixels from the armed edge (the entry
  warp parks the cursor 2 pixels inside that same edge and must not
  fire a push). Once the guard is open and the cursor comes back
  within 2 pixels of the edge, serve emits one
  `return <opposite-edge> <fraction>` line to stdout and disarms.
  An idle unarmed serve polls nothing. When the daemon socket is
  unavailable or the coproc dies, serve reconnects with capped
  backoff and degrades to the plain command loop meanwhile.

Each warp appends one line to `~/.cache/lan-mouse-warp.log` for latency
measurement.

## Files

- `lan-mouse-warp.sh` - the warp and report logic.
- `compositor-query.sh` - shared compositor detection and monitor
  queries for Hyprland and Wayfire, sourced by this script and by
  `lan-mouse-handoff`. Detection works from the runtime directory
  alone, because SSH sessions carry no compositor environment.
- `lan-mouse-wayfire-ipc.py` - stdlib-only Python client for Wayfire's
  length-prefixed JSON IPC. Every Wayfire method name lives in its
  `METHODS` table, because the `stipc` plugin is a test interface and
  a rename upstream should be a single edit here.
- `warp-application.nix` - the shared derivation, imported by this
  module and by `lan-mouse-hookd`.
- `wayfire-ipc.nix` - the helper derivation, shared with
  `lan-mouse-handoff`.

Wayfire needs the `ipc`, `ipc-rules`, and `stipc` plugins enabled;
`stipc/move_cursor` takes global layout coordinates.
