{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf
  (host.is.workstation && noughtyLib.userHasTag "developer" && noughtyLib.isUser [ "martin" ])
  {
    # Prefer standalone TypeScript over Wrangler's bundled copy in the profile.
    home.packages = [ (lib.lowPrio pkgs.wrangler) ];
  }
