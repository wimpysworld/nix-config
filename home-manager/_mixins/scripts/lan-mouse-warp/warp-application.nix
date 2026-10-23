# The lan-mouse-warp application shared by the lan-mouse-warp module
# and lan-mouse-hookd, which runs the local warp on a return crossing.
pkgs:
let
  wayfireIpc = import ./wayfire-ipc.nix pkgs;
in
pkgs.writeShellApplication {
  name = "lan-mouse-warp";
  # mmsg resolves from the session PATH, so it always matches the
  # running Mango instance.
  runtimeInputs = [
    wayfireIpc
  ]
  ++ (with pkgs; [
    coreutils
    findutils
    jq
    wlrctl
  ]);
  text =
    builtins.readFile ./compositor-query.sh
    + pkgs.lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./lan-mouse-warp.sh);
}
