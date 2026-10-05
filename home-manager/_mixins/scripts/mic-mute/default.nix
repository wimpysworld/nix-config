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
      gnused
      fyi
      pulseaudio
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf config.noughty.host.is.linux {
  home.packages = with pkgs; [ shellApplication ];
}
