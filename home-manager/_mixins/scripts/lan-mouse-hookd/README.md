# lan-mouse-hookd

A systemd user service on the compositor session target that makes
proportional cursor placement for
[lan-mouse](https://github.com/feschber/lan-mouse) dynamic and
complete. See `../lan-mouse-handoff/README.md` for why the tooling
exists.

## What it does

**Hook applier.** The daemon's client topology (which machine sits on
which edge) is configured in the lan-mouse GUI and can change at any
time, so it is never declared in Nix. The applier connects to the
daemon's IPC socket, and keeps every client's `enter_hook` set to
`lan-mouse-handoff <hostname> <position> <address>`. A client added,
renamed, or moved in the GUI raises a daemon event and the hook is
rewritten live. The configuration is never saved from here:
`config.toml` stays the GUI's file, and the applier re-applies every
session.

**Return push.** lan-mouse runs no hook on a return crossing (the
controlling host releases its capture when the emulated cursor hits
the peer's screen edge), and Hyprland does not honour the capture's
pointer lock, so the hidden local cursor drifts during a remote
session and reappeared in a surprising place. The peer's
`lan-mouse-warp serve` watcher knows about the return first: its own
cursor touches the session's entry edge, and it pushes one
`return <edge> <fraction>` line over the warp channel. The channel
keeper validates the fraction, checks the pushed edge against the
client's recorded position (so a peer cannot warp an arbitrary edge),
warps the local cursor, and writes a `last-return-<hostname>` marker
in the state directory.

**State and lifecycle.** All state files (`client-<handle>`,
`pos-<hostname>`, `last-return-<hostname>`, `generation`) live in the
fixed directory `$XDG_RUNTIME_DIR/lan-mouse-hookd/`, which survives
restarts, so the marker writer and the marker reader always share one
directory. Stale files are harmless: the applier rewrites them on
every daemon connect, and the marker is timestamp-guarded. At startup
the main process writes its pid to `generation`. The applier, the
follower, and every keeper capture that value at spawn, check the
file before acting, and exit quietly on a mismatch, so a worker
orphaned by an older hookd dies on its first activity instead of
warping twice.

**Return mirror, the fallback.** The follower watches the daemon
journal: `entering client <handle>` opens a session, and
`releasing capture: left remote client device region` marks a return.
journald delivers these lines 300 to 480 ms late, so the follower
first checks the push marker and skips a return the keeper handled
within the last two seconds. Otherwise it asks the peer for its
frozen cursor's fraction with a direct `lan-mouse-warp report` over
SSH and warps the local cursor to the matching fraction on the
client's edge.

**Warp channel.** One keeper per client hostname holds a persistent
`lan-mouse-warp serve` session on the peer over SSH. The keeper feeds
the named pipe `$XDG_RUNTIME_DIR/lan-mouse-chan-<hostname>.in` to ssh
stdin, and it is the only reader of ssh stdout, where the peer's
return pushes arrive. `lan-mouse-handoff` writes one warp line to the
`.in` pipe instead of spawning ssh, so a crossing costs one round
trip. The keeper holds the pipe open read-write, so writers never
block while the channel restarts, and it restarts ssh with capped
backoff when the peer reboots or sleeps. The keeper's connection also
opens the SSH control master that the direct fallback paths reuse.

Every failure path logs and skips. A dead peer degrades to stock
lan-mouse behaviour.
