{ config, lib, pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      fuzzel
      notify-desktop
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf config.wayland.windowManager.hyprland.enable {
  home.packages = with pkgs; [ shellApplication ];
}
