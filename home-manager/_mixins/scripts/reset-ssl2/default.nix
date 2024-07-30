{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils-full
      usb-reset
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (lib.elem hostname installOn) { home.packages = with pkgs; [ shellApplication ]; }
