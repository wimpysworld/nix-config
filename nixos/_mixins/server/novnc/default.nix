{
  lib,
  noughtyLib,
  ...
}:
# wayvnc runs with --websocket so it speaks WebSocket natively. Caddy
# reverse-proxies to it directly (see nixos/_mixins/server/caddy/default.nix).
# No external websockify bridge is needed.
#
# This module is retained as a placeholder to avoid breaking the server hub's
# builtins.readDir auto-import. It can be removed once the directory is deleted.
lib.mkIf (noughtyLib.hostHasTag "wayvnc") { }
