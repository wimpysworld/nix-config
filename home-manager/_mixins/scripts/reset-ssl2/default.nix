{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      usb-reset
      usbutils
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf host.is.linux {
  home.packages = with pkgs; [ shellApplication ];
}
