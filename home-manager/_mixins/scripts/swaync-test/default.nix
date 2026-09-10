{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      fyi
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (config.noughty.host.is.linux && config.noughty.host.is.workstation) {
  home.packages = [ shellApplication ];
}
