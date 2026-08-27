# lan-mouse-handoff

The sender-side enter hook for [lan-mouse](https://github.com/feschber/lan-mouse).
The daemon runs it at the moment the cursor is captured for a client,
that is, when the pointer crosses a screen edge towards another machine.

## Why

The lan-mouse wire protocol carries only an edge name, never the
crossing point, and the receiver applies relative deltas from wherever
its cursor last sat. The cursor therefore arrived anywhere on the
destination screen. Upstream declined to add a position to the protocol
([issue #230](https://github.com/feschber/lan-mouse/issues/230)), so
this hook fixes placement from outside: it reads the crossing point on
the sending machine and asks the peer to warp its cursor to the same
fraction along the matching edge.

## How

`lan-mouse-handoff <client-hostname> <position> <address>`

- The three arguments are baked into the hook command by
  `lan-mouse-hookd`, which rewrites the hook whenever the daemon
  reports a topology change. The hook itself never queries the daemon,
  because every millisecond before the warp is a visible cursor jump on
  the peer (an earlier version queried the daemon and paid a full
  second per crossing).
- It reads the local cursor and monitor layout from the running
  compositor (Hyprland or Wayfire, detected at runtime) and computes
  the fraction along the exit edge of the monitor the cursor is on.
- It writes one `warp <entry-edge> <fraction>` line to the persistent
  warp channel that `lan-mouse-hookd` keeps open to the peer
  (`$XDG_RUNTIME_DIR/lan-mouse-chan-<hostname>.in`), which costs no
  process spawn. When the channel is absent or the write times out,
  it falls back to running `lan-mouse-warp <entry-edge> <fraction>`
  on the peer over multiplexed SSH.
- A hard 250 ms timeout guards the fallback peer call. A dead or
  undeployed peer degrades to stock lan-mouse behaviour, never a
  stalled cursor.

The compositor query functions are shared from
`../lan-mouse-warp/compositor-query.sh`.
