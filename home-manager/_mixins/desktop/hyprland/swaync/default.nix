{ lib, pkgs, ... }:
{
  # swaync is a notification daemon
  services = {
    swaync = {
      enable = true;
      settings = {
        "$schema" = "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json";
        notification-inline-replies = true;
        positionX = "right";
        positionY = "top";
        widgets = [
          #"buttons-grid" #disable for now, not sure I like the extra clutter
          "title"
          "dnd"
          "notifications"
          "mpris"
          "volume"
        ];
        widget-config = {
          buttons-grid.actions = [
            {
              label = "󰹑";
              command = "${lib.getExe pkgs.grimblast} save screen - | ${lib.getExe pkgs.swappy} -f -";
            }
            {
              label = "󱩌";
              command = "notify-desktop NightLight";
            }
            {
              label = "󰍹";
              command = "${lib.getExe pkgs.wdisplays}";
            }
            {
              label = "";
              command = "${lib.getExe pkgs.gnome-usage}";
            }
            {
              label = "󰀝";
              command = "notify-desktop AirplaneMode";
            }
            # 󰀞
            {
              label = "󰐥";
              command = "${lib.getExe pkgs.wlogout} --buttons-per-row 5 --no-span";
            }
          ];
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "󰩹";
          };
          dnd = {
            text = "Do Not Disturb";
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
          font-family: "Work Sans";
          transition: 250ms;
        }

        trough highlight {
          background: #cdd6f4;
        }

        scale trough {
          margin: 0rem 1rem;
          background-color: #313244;
          min-height: 8px;
          min-width: 70px;
        }

        slider {
          background-color: #89b4fa;
        }

        .floating-notifications.background .notification-row .notification-background {
          box-shadow: 0 0 10px 0 rgba(17, 17, 17, 0.8), inset 0 0 0 1px #313244;
          border-radius: 12.6px;
          margin: 18px;
          background-color: #1e1e2e;
          color: #cdd6f4;
          padding: 0;
          opacity: 0.72;
        }

        .floating-notifications.background .notification-row .notification-background .notification {
          padding: 7px;
          border-radius: 12.6px;
        }

        .floating-notifications.background .notification-row .notification-background .notification.critical {
          box-shadow: inset 0 0 7px 0 #f38ba8;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content {
          margin: 7px;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .summary {
          color: #cdd6f4;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .time {
          color: #a6adc8;
        }

        .floating-notifications.background .notification-row .notification-background .notification .notification-content .body {
          color: #cdd6f4;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * {
          min-height: 3.4em;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action {
          border-radius: 7px;
          color: #cdd6f4;
          background-color: #313244;
          box-shadow: inset 0 0 0 1px #45475a;
          margin: 7px;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #313244;
          color: #cdd6f4;
        }

        .floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:active {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #74c7ec;
          color: #cdd6f4;
        }

        .floating-notifications.background .notification-row .notification-background .close-button {
          margin: 7px;
          padding: 2px;
          border-radius: 6.3px;
          color: #1e1e2e;
          background-color: #f38ba8;
        }

        .floating-notifications.background .notification-row .notification-background .close-button:hover {
          background-color: #eba0ac;
          color: #1e1e2e;
        }

        .floating-notifications.background .notification-row .notification-background .close-button:active {
          background-color: #f38ba8;
          color: #1e1e2e;
        }

        .control-center {
          box-shadow: 0 0 25px 0 rgba(17, 17, 17, 0.6), inset 0 0 0 1px #313244;
          border-radius: 12.6px;
          margin: 18px;
          background-color: #1e1e2e;
          color: #cdd6f4;
          padding: 14px;
          opacity: 0.72;
        }

        .control-center .widget-title > label {
          color: #cdd6f4;
          font-size: 1.3em;
        }

        .control-center .widget-title button {
          border-radius: 7px;
          color: #cdd6f4;
          background-color: #313244;
          box-shadow: inset 0 0 0 1px #45475a;
          padding: 8px;
        }

        .control-center .widget-title button:hover {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #585b70;
          color: #cdd6f4;
        }

        .control-center .widget-title button:active {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #74c7ec;
          color: #1e1e2e;
        }

        .control-center .notification-row .notification-background {
          border-radius: 7px;
          color: #cdd6f4;
          background-color: #313244;
          box-shadow: inset 0 0 0 1px #45475a;
          margin-top: 14px;
        }

        .control-center .notification-row .notification-background .notification {
          padding: 7px;
          border-radius: 7px;
        }

        .control-center .notification-row .notification-background .notification.critical {
          box-shadow: inset 0 0 7px 0 #f38ba8;
        }

        .control-center .notification-row .notification-background .notification .notification-content {
          margin: 7px;
        }

        .control-center .notification-row .notification-background .notification .notification-content .summary {
          color: #cdd6f4;
        }

        .control-center .notification-row .notification-background .notification .notification-content .time {
          color: #a6adc8;
        }

        .control-center .notification-row .notification-background .notification .notification-content .body {
          color: #cdd6f4;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * {
          min-height: 3.4em;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action {
          border-radius: 7px;
          color: #cdd6f4;
          background-color: #11111b;
          box-shadow: inset 0 0 0 1px #45475a;
          margin: 7px;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #313244;
          color: #cdd6f4;
        }

        .control-center .notification-row .notification-background .notification > *:last-child > * .notification-action:active {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #74c7ec;
          color: #cdd6f4;
        }

        .control-center .notification-row .notification-background .close-button {
          margin: 7px;
          padding: 2px;
          border-radius: 6.3px;
          color: #1e1e2e;
          background-color: #eba0ac;
        }

        .close-button {
          border-radius: 6.3px;
        }

        .control-center .notification-row .notification-background .close-button:hover {
          background-color: #f38ba8;
          color: #1e1e2e;
        }

        .control-center .notification-row .notification-background .close-button:active {
          background-color: #f38ba8;
          color: #1e1e2e;
        }

        .control-center .notification-row .notification-background:hover {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #7f849c;
          color: #cdd6f4;
        }

        .control-center .notification-row .notification-background:active {
          box-shadow: inset 0 0 0 1px #45475a;
          background-color: #74c7ec;
          color: #cdd6f4;
        }

        .notification.critical progress {
          background-color: #f38ba8;
        }

        .notification.low progress,
        .notification.normal progress {
          background-color: #89b4fa;
        }

        .control-center-dnd {
          margin-top: 5px;
          border-radius: 8px;
          background: #313244;
          border: 1px solid #45475a;
          box-shadow: none;
        }

        .control-center-dnd:checked {
          background: #313244;
        }

        .control-center-dnd slider {
          background: #45475a;
          border-radius: 8px;
        }

        .widget-dnd {
          margin: 0px;
          font-size: 1.1rem;
        }

        .widget-dnd > switch {
          font-size: initial;
          border-radius: 8px;
          background: #313244;
          border: 1px solid #45475a;
          box-shadow: none;
        }

        .widget-dnd > switch:checked {
          background: #313244;
        }

        .widget-dnd > switch slider {
          background: #45475a;
          border-radius: 8px;
          border: 1px solid #6c7086;
        }

        .widget-mpris .widget-mpris-player {
          background: #313244;
          padding: 7px;
        }

        .widget-mpris .widget-mpris-title {
          font-size: 1.2rem;
        }

        .widget-mpris .widget-mpris-subtitle {
          font-size: 0.8rem;
        }

        .widget-menubar > box > .menu-button-bar > button > label {
          font-size: 3rem;
          padding: 0.5rem 2rem;
        }

        .widget-menubar > box > .menu-button-bar > :last-child {
          color: #f38ba8;
        }

        .power-buttons button:hover,
        .powermode-buttons button:hover,
        .screenshot-buttons button:hover {
          background: #313244;
        }

        .control-center .widget-label > label {
          color: #cdd6f4;
          font-size: 2rem;
        }

        .widget-buttons-grid {
          padding-top: 1rem;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button label {
          font-family: "FiraCode Nerd Font Mono";
          font-size: 2rem;
        }

        .widget-volume {
          padding-top: 1rem;
        }

        .widget-volume label {
          font-size: 1.5rem;
          color: #74c7ec;
        }

        .widget-volume trough highlight {
          background: #74c7ec;
        }

        .widget-backlight trough highlight {
          background: #f9e2af;
        }

        .widget-backlight label {
          font-size: 1.5rem;
          color: #f9e2af;
        }

        .widget-backlight .KB {
          padding-bottom: 1rem;
        }

        .image {
          padding-right: 0.5rem;
        }
      '';
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        "CTRL ALT, N, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
      ];
    };
  };
}
