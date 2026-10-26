# compositor-query

Shared compositor detection and queries for Mango and Wayfire. Shared
components use these queries, so they do not speak compositor IPC
themselves.

## Files

- `compositor-query.sh` - the sourceable library: compositor detection,
  monitors, focused output, output scale, toplevel windows and window
  focus. Detection works from the runtime directory alone, so a caller
  with an incomplete compositor environment still finds the session. A
  library function that a consumer does not call needs
  `# shellcheck disable=SC2329`, or the consumer build fails.
- `compositor-query-command.sh` and `package.nix` - the
  `compositor-query` command for session tools: `wleave-session`,
  `fuzzel-capture` and the Mango `xwayland-dpi` service. Consumers
  import `package.nix` with a `let` binding. It is a package, not a
  module, so this directory has no `default.nix` and the compositor hub
  does not import it.
- `wayfire-ipc.py` and `wayfire-ipc.nix` - the `compositor-wayfire-ipc`
  client, a stdlib-only Python client for the length-prefixed JSON IPC
  of Wayfire. Every Wayfire method name lives in its `METHODS` table,
  so an upstream rename is a single edit here.

## Commands

| Command | Output |
| --- | --- |
| `compositor-query monitors` | JSON array of `name`, `x`, `y`, `width` and `height` per output, in logical layout coordinates |
| `compositor-query focused-output` | Name, logical width, logical height and scale of the focused output |
| `compositor-query output-scale <name>` | Scale of the named output |
| `compositor-query windows` | JSON array of toplevel windows with geometry in logical layout coordinates |
| `compositor-query focus-window <id>` | Focuses, raises and shows the window |

## Compositors

Mango detection runs first, because Mango removes its
`$XDG_RUNTIME_DIR/mango-*.sock` socket on exit. The newest socket sets
`MANGO_INSTANCE_SIGNATURE`, and the newest `wayland-*` socket sets
`WAYLAND_DISPLAY` when the environment does not supply it. `mmsg`
reports the monitors and the clients in logical layout
coordinates. `mmsg` comes from the session `PATH`, so it always matches
the running Mango instance.

Wayfire needs the `ipc` and `ipc-rules` plugins. The
`list-outputs` geometry is the layout geometry. Wayfire IPC reports no
output scale, so the Wayfire scale comes from `wlr-randr`.

## Test

The flake check `checks.<system>.compositor-query`
(`lib/tests/compositor-query.nix`) runs the command, `wleave-session`,
`xwayland-dpi` and the `fuzzel-capture` output mapping against fake
compositor tools.
