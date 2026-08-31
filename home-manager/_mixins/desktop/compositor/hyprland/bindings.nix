{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  veilaBin = lib.getExe' veila "veila";
in
{
  config = lib.mkIf (host.desktop == "hyprland") {
    wayland.windowManager.hyprland.settings = {
      # Work when input inhibitor (l) is active.
      bindl = [
        ", XF86AudioPlay, exec, ${lib.getExe pkgs.playerctl} play-pause"
        ", XF86AudioPrev, exec, ${lib.getExe pkgs.playerctl} previous"
        ", XF86AudioNext, exec, ${lib.getExe pkgs.playerctl} next"
        ", XF86AudioMute, exec, ${pkgs.avizo}/bin/volumectl toggle-mute"
        ", XF86AudioMicMute, exec, ${pkgs.avizo}/bin/volumectl -m toggle-mute"
      ];
      # Work when input inhibitor (l) is active, with repeat (e)
      bindle = [
        ", XF86AudioRaiseVolume, exec, ${pkgs.avizo}/bin/volumectl -u up"
        ", XF86AudioLowerVolume, exec, ${pkgs.avizo}/bin/volumectl -u down"
        ", XF86MonBrightnessUp, exec, ${pkgs.avizo}/bin/lightctl up"
        ", XF86MonBrightnessDown, exec, ${pkgs.avizo}/bin/lightctl down"
      ];
      bindr = [
        "$mod, $mod_L, exec, ${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun"
      ];
      bind = [
        "$mod, E, exec, ${pkgs.nautilus}/bin/nautilus --new-window"
      ]
      # Bind the Pause key by keycode (xkb 127 = evdev KEY_PAUSE 119 + 8) because
      # Hyprland does not reliably match the Pause keysym by name.
      ++ lib.optionals config.services.handy.enable (
        [ "$mod, V, exec, ${lib.getExe config.services.handy.package} --toggle-transcription" ]
        ++ lib.optional (
          !host.is.laptop
        ) ", code:127, exec, ${lib.getExe config.services.handy.package} --toggle-transcription"
      )
      ++ [
        "$mod, L, exec, ${veilaBin} lock"
        "CTRL ALT, L, exec, ${veilaBin} lock"
        "CTRL ALT, N, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
        "CTRL ALT, SPACE, exec, fuzzel-session-menu"
        "CTRL ALT, E, exec, fuzzel-emoji"
        "CTRL ALT, P, exec, fuzzel-clipboard"
        "CTRL ALT, R, exec, fuzzel-history"
        ", Print, exec, fuzzel-capture"
        "ALT, Print, exec, fuzzel-capture window"
        "SHIFT, Print, exec, fuzzel-capture region"
        "CTRL ALT, Print, exec, fuzzel-capture output ${display.primaryOutput}"
        "$mod, T, exec, ${lib.getExe config.programs.kitty.package}"
      ];
    };
  };
}
