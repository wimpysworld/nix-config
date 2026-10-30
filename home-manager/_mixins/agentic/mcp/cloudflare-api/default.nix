{
  lib,
  pkgs,
  apiTokenPath,
}:
pkgs.writeShellApplication {
  name = "cloudflare-api";
  runtimeInputs = [ pkgs.coreutils ];
  text =
    builtins.replaceStrings
      [ "@apiTokenPath@" "@mcpProxy@" ]
      [
        (lib.escapeShellArg apiTokenPath)
        (lib.escapeShellArg (lib.getExe pkgs.mcp-proxy))
      ]
      (builtins.readFile ./script.sh);
}
