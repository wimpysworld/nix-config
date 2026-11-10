{
  lib,
  pkgs,
  bridgeDir,
}:
pkgs.writeShellApplication {
  name = "reaper-mcp";
  text =
    builtins.replaceStrings
      [ "@bridgeDir@" "@server@" ]
      [
        (lib.escapeShellArg bridgeDir)
        (lib.escapeShellArg (lib.getExe pkgs.twelvetake-reaper-mcp))
      ]
      (builtins.readFile ./reaper-mcp.sh);
}
