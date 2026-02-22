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
    # Note: fuzzel-wifi, fuzzel-bluetooth, and fuzzel-audio are separate
    # packages installed by the fuzzel component. They are on PATH at runtime
    # so no need to add them to runtimeInputs here.
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf config.wayland.windowManager.hyprland.enable {
  home.packages = [ shellApplication ];
}
