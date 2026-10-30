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
    home.packages = [ pkgs.wrangler ];
  }
