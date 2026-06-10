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
      fuzzel
    ];
    # Note: fuzzel-wifi, fuzzel-bluetooth, fuzzel-audio and wleave-session are
    # provided by other components and are on PATH at runtime, so they are not
    # added to runtimeInputs here.
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf config.wayland.windowManager.hyprland.enable {
  home.packages = [ shellApplication ];
}
