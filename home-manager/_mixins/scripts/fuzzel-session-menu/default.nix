{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ fuzzel ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];
}
