# The compositor-query command, built from compositor-query.sh so that
# session tools share the lan-mouse compositor queries. The test in
# lib/tests/compositor-query.nix passes fake compositor tools as
# compositorTools.
{
  pkgs,
  compositorTools ? [
    (import ./wayfire-ipc.nix pkgs)
    pkgs.wlr-randr
  ],
}:
pkgs.writeShellApplication {
  name = "compositor-query";
  # mmsg resolves from the session PATH, so it always matches the
  # running Mango instance.
  runtimeInputs =
    compositorTools
    ++ (with pkgs; [
      coreutils
      findutils
      jq
    ]);
  text =
    builtins.readFile ./compositor-query.sh
    + pkgs.lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./compositor-query-command.sh);
}
