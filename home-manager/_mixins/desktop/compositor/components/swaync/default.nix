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
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # GTK's symbolic icon node parser ignores SVG group transforms in Papirus icons.
  systemd.user.services.swaync.Service.Environment = [ "GDK_DISABLE=icon-nodes" ];

  # swaync is a notification daemon
  services = {
    swaync = {
      enable = true;
      settings = {
        "$schema" = "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json";
        notification-2fa-action = false;
        notification-inline-replies = true;
        positionX = "right";
        positionY = "top";
        control-center-width = 512;
        widgets = [
          "backlight"
          "volume"
          "mpris"
          "title"
          "dnd"
          "notifications"
        ];
        widget-config = {
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
            show-album-art = "never";
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
          background-color: ${palette.mkRgba "base" "0.9"};
          color: ${palette.getColor "text"};
          padding: 0;
          opacity: 1;
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

        .floating-notifications.background .notification-row .notification-background .close-button {
          margin: 10px;
          padding: 6px;
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
          background-color: ${palette.mkRgba "base" "0.72"};
          color: ${palette.getColor "text"};
          padding: 14px;
          opacity: 1;
        }

        .control-center .widget-title {
          margin-top: 14px;
          margin-bottom: 8px;
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

        .control-center .notification-row .notification-background .close-button {
          margin: 10px;
          padding: 6px;
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
          background-color: ${palette.getColor "surface1"};
          color: ${palette.getColor "text"};
        }

        .control-center .notification-row .notification-background:active {
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface1"};
          background-color: ${palette.getColor "surface2"};
          color: ${palette.getColor "text"};
        }

        .notification .notification-alt-actions {
          padding: 4px;
        }

        .notification .notification-action {
          margin: 3px;
          padding: 0;
        }

        .notification .notification-action > button,
        .notification .inline-reply-button {
          min-height: 28px;
          min-width: 28px;
          padding: 8px;
          border-radius: 8px;
          color: ${palette.getColor "text"};
          background-color: ${palette.getColor "crust"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface2"};
        }

        .notification .notification-action > button label,
        .notification .inline-reply-button label {
          font-family: "Work Sans", "FiraCode Nerd Font Mono";
          font-size: 18px;
          font-weight: 600;
        }

        .notification .notification-action > button:hover,
        .notification .inline-reply-button:hover {
          background-color: ${palette.getColor "surface2"};
        }

        .notification .notification-action > button:active,
        .notification .inline-reply-button:active {
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "crust"};
        }

        .notification .notification-action > button:disabled,
        .notification .inline-reply-button:disabled {
          background-color: ${palette.getColor "surface0"};
          color: ${palette.getColor "overlay1"};
        }

        .notification .inline-reply {
          margin-top: 8px;
        }

        .notification .inline-reply-entry {
          min-height: 28px;
          padding: 8px;
          border-radius: 8px;
          background-color: ${palette.getColor "crust"};
          color: ${palette.getColor "text"};
          caret-color: ${palette.getColor "text"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface2"};
        }

        .notification .inline-reply-entry text {
          font-family: "Work Sans";
          font-size: 18px;
        }

        .notification .inline-reply-entry text > placeholder {
          color: ${palette.getColor "subtext0"};
        }

        .notification .inline-reply-entry text > selection {
          background-color: ${palette.getColor "sapphire"};
          color: ${palette.getColor "crust"};
        }

        .notification .inline-reply-button {
          margin-left: 8px;
        }

        .notification .inline-reply-entry:focus-within,
        .notification .inline-reply-button:focus-visible,
        .notification .notification-action > button:focus-visible,
        .notification-background .close-button:focus-visible {
          outline: 2px solid ${palette.getColor "sapphire"};
          outline-offset: -2px;
        }

        .notification-row:focus .notification-background,
        .notification-group.collapsed:focus .notification-row:last-child .notification-background,
        .notification-group:not(.collapsed):focus {
          outline: 2px solid ${palette.getColor "sapphire"};
          outline-offset: -2px;
          border-radius: 8px;
        }

        .notification .notification-content {
          padding-right: 24px;
        }

        .notification .notification-content > picture {
          margin-top: 8px;
          border-radius: 8px;
        }

        .notification progressbar {
          margin-top: 8px;
          margin-bottom: 4px;
        }

        .notification progressbar trough {
          min-height: 8px;
          border-radius: 4px;
          background-color: ${palette.getColor "crust"};
          box-shadow: inset 0 0 0 1px ${palette.getColor "surface2"};
        }

        .notification progressbar progress {
          min-height: 8px;
          min-width: 0;
          border-radius: 4px;
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
          min-width: 512px;
          min-height: 512px;
          margin: 0;
          padding: 0;
          background: ${palette.getColor "surface0"};
          border-radius: 14px;
        }

        .widget-mpris .mpris-background {
          filter: none;
        }

        .widget-mpris .mpris-overlay {
          padding: 24px;
          background: linear-gradient(
            to bottom,
            ${palette.mkRgba "crust" "0.05"} 0%,
            ${palette.mkRgba "crust" "0.2"} 20%,
            ${palette.mkRgba "crust" "0.76"} 40%,
            ${palette.mkRgba "crust" "0.76"} 55%,
            ${palette.mkRgba "crust" "0.5"} 70%,
            ${palette.mkRgba "crust" "0.9"} 100%
          );
        }

        .widget-mpris .mpris-overlay > box:first-child > box {
          margin: 0 8px;
        }

        .widget-mpris .mpris-overlay > box:last-child {
          margin-top: 20px;
        }

        .widget-mpris .mpris-overlay button {
          color: ${palette.getColor "text"};
          background: ${palette.mkRgba "text" "0.1"};
          min-width: 24px;
          min-height: 24px;
          margin: 0 4px;
          padding: 10px;
          border-radius: 50%;
        }

        .widget-mpris .mpris-overlay button image {
          -gtk-icon-size: 24px;
          min-width: 24px;
          min-height: 24px;
          margin: 0;
          padding: 0;
        }

        .widget-mpris .mpris-overlay button:nth-child(3) {
          background: ${palette.getColor "text"};
          color: ${palette.getColor "crust"};
        }

        .widget-mpris .mpris-overlay button:hover {
          background: ${palette.getColor "surface2"};
          color: ${palette.getColor "text"};
        }

        .widget-mpris .mpris-overlay button:focus-visible {
          outline: 2px solid ${palette.getColor "sapphire"};
          outline-offset: 3px;
        }

        .widget-mpris .mpris-overlay button:active,
        .widget-mpris .mpris-overlay button:checked {
          background: ${palette.getColor "sapphire"};
          color: ${palette.getColor "base"};
        }

        .widget-mpris .mpris-overlay button:disabled {
          color: ${palette.getColor "overlay1"};
          background: transparent;
        }

        .widget-mpris .widget-mpris-title {
          color: ${palette.getColor "text"};
          font-family: "Work Sans";
          font-size: 28px;
          font-weight: 700;
          text-shadow: 0 1px 3px ${palette.getColor "crust"};
        }

        .widget-mpris .widget-mpris-subtitle {
          color: ${palette.getColor "subtext1"};
          font-family: "Work Sans";
          font-size: 18px;
          text-shadow: 0 1px 3px ${palette.getColor "crust"};
        }

        .control-center .widget-label > label {
          color: ${palette.getColor "text"};
          font-size: 2rem;
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
          -gtk-icon-size: 64px;
          min-width: 64px;
          min-height: 64px;
        }

        .app-icon {
          -gtk-icon-size: 21px;
          min-width: 21px;
          min-height: 21px;
        }
      '';
    };
  };
}
