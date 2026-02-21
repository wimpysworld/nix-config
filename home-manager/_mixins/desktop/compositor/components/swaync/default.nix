{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
  swayncRun = pkgs.writeShellApplication {
    name = "swaync-run";
    text = ''
      # Execute all arguments as a single command
      # Check if any arguments were provided
      if [ $# -ge 1 ]; then
        # Close the swaync panel
        swaync-client --close-panel --skip-wait
        # Execute all arguments as a single command
        exec "$@"
      fi
    '';
  };
in
lib.mkIf host.is.linux {
  # swaync is a notification daemon
  services = {
    swaync = {
      enable = true;
      settings = {
        "$schema" = "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json";
        notification-2fa-action = false;
        notification-inline-replies = false;
        positionX = "right";
        positionY = "top";
        widgets = [
          "menubar"
          "buttons-grid"
          "backlight"
          "volume"
          "mpris"
          "title"
          "dnd"
          "notifications"
        ];
        widget-config = {
          menubar = {
            "menu#screenshot-buttons" = {
              label = "󰄀";
              position = "left";
              actions = [
                {
                  label = "󰹑  Screenshot  ";
                  command = "${lib.getExe swayncRun} fuzzel-hyprshot";
                }
                {
                  label = "󰏘  Color Picker";
                  command = "${lib.getExe swayncRun} fuzzel-hyprpicker";
                }
              ];
            };
            "menu#powermode-buttons" = {
              label = "󱐋";
              position = "right";
              actions = [
                {
                  label = "󰤇  Performance";
                  command = "powerprofilesctl set performance";
                }
                {
                  label = "󰗑  Balanced   ";
                  command = "powerprofilesctl set balanced";
                }
                {
                  label = "󰴻  Power-saver";
                  command = "powerprofilesctl set power-saver";
                }
              ];
            };
            "menu#power-buttons" = {
              label = "󰐦";
              position = "right";
              actions = [
                {
                  label = "󰌾  Lock    ";
                  command = "${lib.getExe swayncRun} hypr-session lock";
                }
                {
                  label = "󰗽  Logout  ";
                  command = "${lib.getExe swayncRun} hypr-session logout";
                }
                {
                  label = "󱍷  Reboot  ";
                  command = "${lib.getExe swayncRun} hypr-session reboot";
                }
                {
                  label = "󰤄  Suspend ";
                  command = "${lib.getExe swayncRun} systemctl suspend";
                }
                {
                  label = "  Shutdown";
                  command = "${lib.getExe swayncRun} hypr-session shutdown";
                }
              ];
            };
          };
          buttons-grid.actions = [
            {
              label = "󰕾";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.pwvucontrol}";
            }
            {
              label = "󱑽";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.easyeffects}";
            }
            {
              label = "";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.overskride}";
            }
            {
              label = "󰈀";
              command = "${lib.getExe swayncRun} ${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
            }
            {
              label = "󰖩";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.iwgtk}";
            }
            {
              label = "󰴳";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.trayscale}";
            }
            {
              label = "󱁗";
              command = "${lib.getExe swayncRun} ${pkgs.system-config-printer}/bin/system-config-printer";
            }
            {
              label = "󱋆";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.wdisplays}";
            }
            {
              label = "󰧹";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.input-remapper}";
            }
            {
              label = "";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.piper}";
            }
            {
              label = "󰋊";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.gnome-disk-utility}";
            }
            {
              label = "󱊞";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.usbimager}";
            }
            {
              label = "";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.cpu-x}";
            }
            {
              label = "󰉁";
              command = "${lib.getExe swayncRun} ${lib.getExe pkgs.gnome-firmware}";
            }
          ];
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = " 󰩹 ";
          };
          dnd = {
            text = "Do Not Disturb";
          };
          backlight = {
            label = "󰃟";
          };
          mpris = {
            blur = true;
          };
          volume = {
            label = "󰓃";
            show-per-app = false;
          };
        };
      };
      # https://github.com/catppuccin/swaync
      # 0.2.3 (mocha)
      style = ''
        * {
          all: unset;
          font-size: 20px;
          font-family: "FiraCode Nerd Font Mono";
          transition: 250ms;
        }

        trough highlight {
          background: ${palette.getColor "text"};
        }

        scale trough {
          margin: 0rem 1rem;
          background-color: ${palette.getColor "surface0"};
          min-height: 8px;
          min-width: 70px;
        }

        slider {
          background-color: ${palette.getColor "blue"};
        }

        .floating-notifications.background .notification-row .notification-background {
          box-shadow: 0 0 10px 0 rgba(17, 17, 17, 0.8), inset 0 0 0 1px ${palette.getColor "surface0"};
          border-radius: 12.6px;
          margin: 18px;
          background-color: ${palette.getColor "base"};
          color: ${palette.getColor "text"};
          padding: 0;
          opacity: 0.72;
        }

        .floating-notifications.background .notification-row .notification-background .notification {
          padding: 7px;
          border-radius: 12.6px;
        }

        .floating-notifications.background .notification-row .notification-background .notification.critical {
          box-shadow: inset 0 0 7px 0 ${palette.getColor "red"};
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content {
          margin: 7px;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .summary {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 1.4rem;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .time {
          color: ${palette.getColor "subtext0"};
          font-family: "Work Sans";
          font-size: 1.0rem;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .body {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 1.2rem;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * {
          min-height: 3.4em;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action {
          border-radius: 7px;
          color: ${palette.getColor "text"};
          background-color: ${palette.getColor "surface0"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          margin: 7px;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "surface0"};
          color: ${palette.getColor "text"};
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:active {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "text"};
        }

        .floating-notifications.background .notification-row .notification-background .close-button {
          margin: 7px;
          padding: 2px;
          border-radius: 6.3px;
          color: ${palette.getColor "base"};
          background-color: ${palette.getColor "red"};
        }

        .floating-notifications.background .notification-row .notification-background .close-button:hover {
          background-color: ${palette.getColor "maroon"};
          color: ${palette.getColor "base"};
        }

        .floating-notifications.background .notification-row .notification-background .close-button:active {
          background-color: ${palette.getColor "red"};
          color: ${palette.getColor "base"};
        }

        .control-center {
          box-shadow: 0 0 25px 0 rgba(17, 17, 17, 0.6), inset 0 0 0 1px ${palette.getColor "surface0"};
          border-radius: 12.6px;
          margin: 18px;
          background-color: ${palette.getColor "base"};
          color: ${palette.getColor "text"};
          padding: 14px;
          opacity: 0.72;
        }

        .control-center .widget-title > label {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 1.3em;
        }

        .control-center .widget-title button {
          border-radius: 7px;
          color: ${palette.getColor "text"};
          background-color: ${palette.getColor "surface0"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          padding: 8px;
        }

        .control-center .widget-title button:hover {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "surface2"};
          color: ${palette.getColor "text"};
        }

        .control-center .widget-title button:active {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "base"};
        }

        .control-center .notification-row .notification-background {
          border-radius: 7px;
          color: ${palette.getColor "text"};
          background-color: ${palette.getColor "surface0"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          margin-top: 14px;
        }

        .control-center .notification-row .notification-background .notification {
          padding: 7px;
          border-radius: 7px;
        }

        .control-center .notification-row .notification-background .notification.critical {
          box-shadow: inset 0 0 7px 0 ${palette.getColor "red"};
        }

        .control-center .notification-row .notification-background .notification .notification-content {
          margin: 7px;
        }

        .control-center .notification-row .notification-background .notification .notification-content .summary {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 1.4rem;
        }

        .control-center .notification-row .notification-background .notification .notification-content .time {
          color: ${palette.getColor "subtext0"};
          font-family: "Work Sans";
          font-size: 1.0rem;
        }

        .control-center .notification-row .notification-background .notification .notification-content .body {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 1.2rem;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * {
          min-height: 3.4em;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action {
          border-radius: 7px;
          color: ${palette.getColor "text"};
          background-color: ${palette.getColor "crust"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          margin: 7px;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "surface0"};
          color: ${palette.getColor "text"};
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action:active {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "text"};
        }

        .control-center .notification-row .notification-background .close-button {
          margin: 7px;
          padding: 2px;
          border-radius: 6.3px;
          color: ${palette.getColor "base"};
          background-color: ${palette.getColor "maroon"};
        }

        .close-button {
          border-radius: 6.3px;
        }

        .control-center .notification-row .notification-background .close-button:hover {
          background-color: ${palette.getColor "red"};
          color: ${palette.getColor "base"};
        }

        .control-center .notification-row .notification-background .close-button:active {
          background-color: ${palette.getColor "red"};
          color: ${palette.getColor "base"};
        }

        .control-center .notification-row .notification-background:hover {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "overlay1"};
          color: ${palette.getColor "text"};
        }

        .control-center .notification-row .notification-background:active {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "text"};
        }

        .notification.critical progress {
          background-color: ${palette.getColor "red"};
        }

        .notification.low progress,
        .notification.normal progress {
          background-color: ${palette.getColor "blue"};
        }

        .control-center-dnd {
          margin-top: 5px;
          border-radius: 8px;
          background: ${palette.getColor "surface0"};
          border: 1px solid ${palette.getColor "surface1"};
          box-shadow: none;
        }

        .control-center-dnd:checked {
          background: ${palette.getColor "surface0"};
        }

        .control-center-dnd slider {
          background: ${palette.getColor "surface1"};
          border-radius: 8px;
        }

        .widget-dnd {
          margin: 0px;
          font-family: "Work Sans";
          font-size: 1.1rem;
        }

        .widget-dnd > switch {
          font-size: initial;
          border-radius: 8px;
          background: ${palette.getColor "surface0"};
          border: 1px solid ${palette.getColor "surface1"};
          box-shadow: none;
        }

        .widget-dnd > switch:checked {
          background: ${palette.getColor "surface0"};
        }

        .widget-dnd > switch slider {
          background: ${palette.getColor "surface1"};
          border-radius: 8px;
          border: 1px solid ${palette.getColor "overlay0"};
        }

        .widget-mpris .widget-mpris-player {
          background: ${palette.getColor "surface0"};
          padding: 7px;
        }

        .widget-mpris .widget-mpris-title {
          font-family: "Work Sans";
          font-size: 1.2rem;
        }

        .widget-mpris .widget-mpris-subtitle {
          font-family: "Work Sans";
          font-size: 0.8rem;
        }

        .widget-menubar > box > .menu-button-bar > button > label {
          font-size: 1.5rem;
          padding: 0 1rem;
        }

        .widget-menubar > box > .menu-button-bar > :nth-last-child(2) {
          color: ${palette.getColor "yellow"};
        }

        .widget-menubar > box > .menu-button-bar > :last-child {
          color: ${palette.getColor "red"};
          padding: 0 0;
        }

        .power-buttons button:hover,
        .powermode-buttons button:hover,
        .screenshot-buttons button:hover {
          background: ${palette.getColor "surface0"};
        }

        .control-center .widget-label > label {
          color: ${palette.getColor "text"};
          font-size: 2rem;
        }

        .widget-buttons-grid {
          padding-top: 0.5rem;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button label {
          font-size: 2.5rem;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button:hover label {
          color: ${palette.getColor "blue"};
        }

        .widget-volume {
          padding-top: 1rem;
          padding-bottom: 1rem;
        }

        .widget-volume label {
          font-size: 1.5rem;
          color: ${palette.getColor "sapphire"};
        }

        .widget-volume trough highlight {
          background: ${palette.getColor "sapphire"};
        }

        .widget-backlight trough highlight {
          background: ${palette.getColor "yellow"};
        }

        .widget-backlight label {
          font-size: 1.5rem;
          color: ${palette.getColor "yellow"};
        }

        .widget-backlight .KB {
          padding-top: 1rem;
          padding-bottom: 1rem;
        }

        .image {
          padding-right: 0.5rem;
        }
      '';
    };
  };
  wayland.windowManager = {
    hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
      settings = {
        bind = [
          "CTRL ALT, N, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
        ];
      };
    };
    wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
      settings = {
        command = {
          binding_notifications = "<ctrl> <alt> KEY_N";
          command_notifications = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";
        };
      };
    };
  };
}
