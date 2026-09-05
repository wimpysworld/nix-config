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
  config = lib.mkIf (host.desktop == "wayfire") {
    wayland.windowManager.wayfire.settings = {
      autostart.rofi = false;
      command = {
        binding_files = "<super> KEY_E";
        command_files = "${lib.getExe pkgs.nautilus} --new-window";

        binding_play_pause = "KEY_PLAYPAUSE";
        command_play_pause = "${lib.getExe pkgs.playerctl} play-pause";
        binding_previous = "KEY_PREVIOUS";
        command_previous = "${lib.getExe pkgs.playerctl} previous";
        binding_next = "KEY_NEXT";
        command_next = "${lib.getExe pkgs.playerctl} next";

        binding_mute = "KEY_MUTE";
        command_mute = "${pkgs.avizo}/bin/volumectl toggle-mute";
        binding_micmute = "KEY_MICMUTE";
        command_micmute = "${pkgs.avizo}/bin/volumectl -m toggle-mute";
        binding_volumeup = "KEY_VOLUMEUP";
        command_volumeup = "${pkgs.avizo}/bin/volumectl -u up";
        binding_volumedown = "KEY_VOLUMEDOWN";
        command_volumedown = "${pkgs.avizo}/bin/volumectl -u down";
        binding_brightnessup = "KEY_BRIGHTNESSUP";
        command_brightnessup = "${pkgs.avizo}/bin/lightctl up";
        binding_brightnessdown = "KEY_BRIGHTNESSDOWN";
        command_brightnessdown = "${pkgs.avizo}/bin/lightctl down";

        binding_capture_menu = "KEY_SYSRQ";
        command_capture_menu = "fuzzel-capture";
        binding_capture_window = "<alt> KEY_SYSRQ";
        command_capture_window = "fuzzel-capture window";
        binding_capture_region = "<shift> KEY_SYSRQ";
        command_capture_region = "fuzzel-capture region";
        binding_capture_output = "<ctrl> <alt> KEY_SYSRQ";
        command_capture_output = "fuzzel-capture output ${display.primaryOutput}";

        binding_bluetooth = "<ctrl> <alt> KEY_B";
        command_bluetooth = "fuzzel-bluetooth";
        binding_emoji = "<ctrl> <alt> KEY_E";
        command_emoji = "fuzzel-emoji";
        binding_clipboard = "<ctrl> <alt> KEY_P";
        command_clipboard = "fuzzel-clipboard";
        binding_history = "<ctrl> <alt> KEY_R";
        command_history = "fuzzel-history";
        binding_session = "<ctrl> <alt> KEY_SPACE";
        command_session = "fuzzel-session-menu";
        binding_wifi = "<ctrl> <alt> KEY_W";
        command_wifi = "fuzzel-wifi";

        binding_launcher = "<super>";
        command_launcher = "${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun";

        binding_notifications = "<ctrl> <alt> KEY_N";
        command_notifications = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";

        binding_lock = "<super> KEY_L";
        command_lock = "${veilaBin} lock";
        binding_lock_alternate = "<ctrl> <alt> KEY_L";
        command_lock_alternate = "${veilaBin} lock";

        binding_terminal = "<super> KEY_T";
        command_terminal = lib.getExe pkgs.xdg-terminal-exec;
      }
      // lib.optionalAttrs config.services.handy.enable {
        binding_handy = "<super> KEY_V";
        command_handy = "${lib.getExe config.services.handy.package} --toggle-transcription";
      }
      // lib.optionalAttrs (config.services.handy.enable && !host.is.laptop) {
        binding_handy_pause = "KEY_PAUSE";
        command_handy_pause = "${lib.getExe config.services.handy.package} --toggle-transcription";
      };
    };
  };
}
