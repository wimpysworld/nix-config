{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # The application lives in warp-application.nix so lan-mouse-hookd
  # can share the same derivation through its runtimeInputs.
  shellApplication = import ./warp-application.nix pkgs;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = [ shellApplication ];
}
