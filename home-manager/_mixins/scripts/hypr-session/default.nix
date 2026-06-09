{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [
      veila
    ]
    ++ (with pkgs; [
      bluez
      coreutils
      gnused
      playerctl
      procps
    ]);
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf config.wayland.windowManager.hyprland.enable {
  home.packages = with pkgs; [ shellApplication ];
}
