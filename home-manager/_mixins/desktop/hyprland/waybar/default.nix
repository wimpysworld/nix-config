{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  wlogoutMargins =
    if hostname == "vader" then
      "--margin-top 960 --margin-bottom 960"
    else if hostname == "phasma" then
      "--margin-left 540 --margin-right 540"
    else
      "";
  outputDisplay = if (hostname == "vader" || hostname == "phasma") then "DP-1" else "eDP-1";
  hwmonPath =
    if (hostname == "vader" || hostname == "phasma") then
      "/sys/class/hwmon/hwmon4/temp1_input"
    else if hostname == "tanis" then
      "/sys/class/hwmon/hwmon3/temp1_input"
    else
      "/sys/class/hwmon/hwmon0/temp1_input";
  bluetoothToggle = pkgs.writeShellApplication {
    name = "bluetooth-toggle";
    runtimeInputs = with pkgs; [
      bluez
      gawk
      gnugrep
    ];
    text = builtins.readFile ./bluetooth-toggle.sh;
  };
  eyecandyCheck = pkgs.writeShellApplication {
    name = "eyecandy-check";
    runtimeInputs = with pkgs; [
      gawk
      jq
      uutils-findutils
    ];
    text = builtins.readFile ./eyecandy-check.sh;
  };
  eyecandyToggle = pkgs.writeShellApplication {
    name = "eyecandy-toggle";
    runtimeInputs = with pkgs; [
      gawk
      jq
      notify-desktop
      uutils-findutils
    ];
    # https://github.com/hyprwm/Hyprland/issues/3655#issuecomment-1784217814
    text = builtins.readFile ./eyecandy-toggle.sh;
  };
  rofiAppGrid = pkgs.writeShellApplication {
    name = "rofi-appgrid";
    runtimeInputs = with pkgs; [
      rofi-wayland
    ];
    text = ''
      rofi -show drun -theme "${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi"
    '';
  };
  tailscaleCheck = pkgs.writeShellApplication {
    name = "tailscale-check";
    runtimeInputs = with pkgs; [
      jq
      tailscale
    ];
    text = builtins.readFile ./tailscale-check.sh;
  };
  tailscaleToggle = pkgs.writeShellApplication {
    name = "tailscale-toggle";
    runtimeInputs = with pkgs; [
      jq
      notify-desktop
      tailscale
    ];
    text = builtins.readFile ./tailscale-toggle.sh;
  };
  virtualcamCheck = pkgs.writeShellApplication {
    name = "virtualcam-check";
    runtimeInputs = with pkgs; [
      gnugrep
      uutils-coreutils
    ];
    text = builtins.readFile ./virtualcam-check.sh;
  };
  virtualcamToggle = pkgs.writeShellApplication {
    name = "virtualcam-toggle";
    runtimeInputs = with pkgs; [
      gnugrep
      notify-desktop
      uutils-coreutils
    ];
    text = builtins.readFile ./virtualcam-toggle.sh;
  };
in
{
  # Just use trayscale as a UI
  dconf.settings = with lib.hm.gvariant; {
    "dev/deedles/Trayscale" = {
      tray-icon = false;
    };
  };
  home = {
    file."${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi".source = ./style.rasi;
  };
  programs = {
    waybar = {
      enable = true;
      style = ''
        * {
          font-family: FiraCode Nerd Font Mono;
          font-size: 22px;
          min-height: 0;
        }

        tooltip {
          background: @mantle;
          opacity: 0.95;
          border: 1px solid @blue;
        }

        tooltip label {
          color: @text;
          font-family: Work Sans;
          font-size: 18px;
        }

        #waybar {
          background: transparent;
          color: @text;
          margin: 5px 0 0 0;
        }

        #custom-launcher {
          background-color: @base;
          border-radius: 0.75rem;
          color: @sapphire;
          margin: 5px 0 0 0;
          margin-left: 0.5rem;
          opacity: 0.9;
          padding: 0.25rem 0.75rem;
        }

        #custom-launcher:hover {
          background-color: #242536;
        }

        #workspaces {
          border-radius: 0.75rem;
          background-color: @base;
          margin: 5px 0 0 0.5rem;
          margin-left: 1rem;
          opacity: 0.9;
        }

        #workspaces button {
          border-radius: 0.75rem;
          color: @mauve;
          padding: 0.25rem 0.75rem;
        }

        #workspaces button.active {
          color: @peach;
        }

        #workspaces button:hover {
          background-color: @mantle;
        }

        #idle_inhibitor {
          border-radius: 0.75rem 0 0 0.75rem;
          color: @flamingo;
        }

        #custom-eyecandy {
          color: @flamingo;
        }

        #clock {
          color: @rosewater;
          font-size: 16px;
        }

        #custom-calendar {
          color: @flamingo;
        }

        #custom-swaync {
          border-radius: 0 0.75rem 0.75rem 0;
          color: @flamingo;
        }

        #idle_inhibitor,
        #custom-eyecandy,
        #clock,
        #custom-calendar,
        #custom-swaync {
          background-color: @base;
          margin: 5px 0 0 0;
          padding: 0.25rem 0.75rem;
          opacity: 0.9;
        }

        #idle_inhibitor:hover,
        #custom-eyecandy:hover,
        #clock:hover,
        #custom-calendar:hover,
        #custom-swaync:hover {
          background-color: #242536;
        }

        #tray {
          margin-right: 1rem;
          border-radius: 0.75rem;
        }

        #tray menu * {
          font-family: Work Sans;
          font-size: 18px;
        }

        #tray,
        #custom-virtualcam,
        #wireplumber,
        #pulseaudio.input,
        #bluetooth,
        #network,
        #custom-vpn,
        #battery,
        #backlight,
        #cpu,
        #temperature,
        #power-profiles-daemon,
        #custom-session {
          background-color: @base;
          margin: 5px 0 0 0;
          padding: 0.25rem 0.75rem;
          opacity: 0.9;
        }

        #custom-virtualcam:hover,
        #wireplumber:hover,
        #pulseaudio.input:hover,
        #bluetooth:hover,
        #network:hover,
        #custom-vpn:hover,
        #battery:hover,
        #backlight:hover,
        #cpu:hover,
        #temperature:hover,
        #power-profiles-daemon:hover,
        #custom-session:hover {
          background-color: #242536;
        }


        #wireplumber {
          color: @mauve;
          border-radius: 0.75rem 0 0 0.75rem;
          margin-left: 1rem;
        }

        #pulseaudio.input {
          border-radius: 0;
          color: @mauve;
        }

        #custom-virtualcam {
          border-radius: 0;
          color: @mauve;
        }

        #bluetooth {
          border-radius: 0;
          color: @blue;
        }

        #network {
          border-radius: 0;
          color: @sapphire;
        }

        #custom-vpn {
          border-radius: 0;
          color: @sky;
        }

        #battery {
          border-radius: 0;
          color: @green;
        }

        #battery.charging {
          color: @green;
        }

        #battery.warning:not(.charging) {
          color: @red;
        }

        #backlight {
          border-radius: 0;
          color: @yellow;
        }

        #cpu {
          border-radius: 0;
          color: @teal;
        }

        #temperature {
          border-radius: 0;
          color: @peach;
        }

        #temperature.critical {
          color: @red;
        }

        #power-profiles-daemon {
          border-radius: 0 0.75rem 0.75rem 0;
          color: @maroon;
          font-size: 25px;
          margin-right: 1rem;
        }

        #custom-session {
          border-radius: 0.75rem;
          color: @red;
          margin-right: 0.5rem;
        }
      '';
      settings = [
        {
          exclusive = true;
          output = outputDisplay;
          layer = "bottom";
          position = "top";
          modules-left = [
            "custom/launcher"
            "hyprland/workspaces"
          ];
          modules-center = [
            "idle_inhibitor"
            "custom/eyecandy"
            "clock"
            "custom/calendar"
            "custom/swaync"
          ];
          modules-right = [
            "tray"
            "wireplumber"
            "pulseaudio#input"
          ]
          ++ lib.optional (hostname == "vader" || hostname == "phasma") "custom/virtualcam"
          ++ [
            "bluetooth"
            "network"
            "custom/vpn"
            "battery"
            "backlight"
            "cpu"
            "temperature"
            "power-profiles-daemon"
            "custom/session"
          ];
          "custom/launcher" = {
            format = "<big>󱄅</big>";
            on-click = "${lib.getExe rofiAppGrid}";
            on-click-right = "hypr-activity-menu";
            tooltip-format = "  Applications Menu";
          };
          "hyprland/workspaces" = {
            active-only = false;
            all-outputs = true;
            format = "<big>{icon}</big>";
            format-icons = {
              "1" = "󰖟";
              "2" = "󱒔";
              "3" = "";
              "4" = "";
              "5" = "󰊢";
              "6" = "󰠮";
              "7" = "󰙴";
              "8" = "";
              "9" = "󱆃";
              "10" = "";
              default = "";
            };
            on-click = "activate";
          };
          idle_inhibitor = {
            format = "<big>{icon}</big>";
            format-icons = {
              activated = "<span foreground='#f5c2e7'>󰅶</span>";
              deactivated = "󰾪";
            };
            start-activated = false;
            tooltip-format-activated = "󰅶  Caffeination {status}";
            tooltip-format-deactivated = "󰾪  Caffeination {status}";
          };
          "custom/eyecandy" = {
            format = "<big>{}</big>";
            max-length = 2;
            interval = 1;
            exec = "${lib.getExe eyecandyCheck}";
            on-click = "${lib.getExe eyecandyToggle}";
          };
          clock = {
            actions = {
              on-click-middle = "shift_down";
              on-click-right = "shift_up";
            };
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              on-scroll = 1;
              weeks-pos = "right";
              format = {
                days = "<span color='#cdd6f4'><b>{}</b></span>";
                months = "<span color='#89b4fa'><b>{}</b></span>";
                weeks = "<span color='#74c7ec'><b>󱦰{}</b></span>";
                weekdays = "<span color='#fab387'><b>{}</b></span>";
                today = "<span color='#f38ba8'><b>{}</b></span>";
              };
            };
            format = "<big>{:%H:%M}</big>";
            format-alt = "{:%a, %d %b %R}";
            interval = 60;
            tooltip-format = "<tt><small>{calendar}</small></tt>";
          };
          "custom/calendar" = {
            format = "<big>󰔠</big>";
            max-length = 2;
            on-click = "${lib.getExe pkgs.gnome-calendar}";
            on-click-middle = "${lib.getExe pkgs.mousam}";
            on-click-right = "${lib.getExe pkgs.gnome-clocks}";
            tooltip-format = "󰸗  Calendar (left-click)\n󰼳  Weather (middle-click)\n󱎫  Clock (right-click)";
          };
          #https://haseebmajid.dev/posts/2024-03-15-til-how-to-get-swaync-to-play-nice-with-waybar/
          "custom/swaync" = {
            format = "<big>{icon}</big>";
            format-icons = {
              none = "";
              notification = "<span foreground='#f5c2e7'>󱅫</span>";
              dnd-none = "󰂠";
              dnd-notification = "󱅫";
              inhibited-none = "";
              inhibited-notification = "<span foreground='#f5c2e7'>󰅸</span>";
              dnd-inhibited-none = "󰪓";
              dnd-inhibited-notification = "󰅸";
            };
            max-length = 3;
            return-type = "json";
            escape = true;
            exec-if = "which ${pkgs.swaynotificationcenter}/bin/swaync-client";
            exec = "${pkgs.swaynotificationcenter}/bin/swaync-client --subscribe-waybar";
            on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";
            on-click-middle = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-dnd --skip-wait";
            tooltip-format = "󰵚  {} notification(s)";
          };
          tray = {
            icon-size = 22;
            spacing = 12;
          };
          "custom/virtualcam" = {
            format = "<big>{}</big>";
            exec = "${lib.getExe virtualcamCheck}";
            on-click = "${lib.getExe virtualcamToggle}";
            interval = 1;
            max-length = 2;
          };
          wireplumber = {
            scroll-step = 5;
            format = "<big>{icon}</big>";
            format-alt = "<big>{icon}</big> <small>{volume}󰏰</small>";
            format-muted = "󰖁";
            format-icons = {
              default = [
                "󰕿"
                "󰖀"
                "󰕾"
              ];
            };
            max-volume = 100;
            on-click-middle = "${pkgs.avizo}/bin/volumectl -d -u toggle-mute";
            on-scroll-up = "${pkgs.avizo}/bin/volumectl -d -u up 2";
            on-scroll-down = "${pkgs.avizo}/bin/volumectl -d -u down 2";
            tooltip-format = "󰓃  {volume}󰏰\n󰒓  {node_name}";
          };
          "pulseaudio#input" = {
            format = "<big>{format_source}</big>";
            format-alt = "<big>{format_source}</big> <small>{source_volume}󰏰</small>";
            format-source = "󰍬";
            format-source-muted = "󰍭";
            on-click-middle = "${pkgs.avizo}/bin/volumectl -d -m toggle-mute";
            on-scroll-up = "${pkgs.avizo}/bin/volumectl -d -m up 2";
            on-scroll-down = "${pkgs.avizo}/bin/volumectl -d -m down 2";
            tooltip-format = "  {source_volume}󰏰\n󰒓  {desc}";
            ignored-sinks = [
              "Easy Effects Sink"
              "INZONE Buds Analog Stereo"
            ];
          };
          network = {
            format = "<big>{icon}</big>";
            format-alt = " <small>{bandwidthDownBits}</small>  <small>{bandwidthUpBits}</small>";
            format-ethernet = "󰈀";
            format-disconnected = "󰲜";
            format-linked = "";
            format-wifi = "󰖩";
            interval = 2;
            # todo: add toggle netowrk on/off
            #on-click-middle = "hyprctl dispatch exec [workspace current] ${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
            tooltip-format = "  {ifname}\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
            tooltip-format-wifi = "󱛁  {essid} \n󰒢  {signalStrength}󰏰\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
            tooltip-format-ethernet = "󰈀  {ifname}\n󰩠  {ipaddr} via {gwaddr})\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
            tooltip-format-disconnected = "󰲜  disconnected";
          };
          "custom/vpn" = {
            format = "<big>{}</big>";
            exec = "${lib.getExe tailscaleCheck}";
            on-click-middle = "${lib.getExe tailscaleToggle} toggle";
            on-click-right = "${lib.getExe tailscaleToggle} toggle-mullvad";
            interval = 2;
          };
          bluetooth = {
            format = "<big>{icon}</big>";
            format-connected = "󰂱";
            format-disabled = "󰂲";
            format-on = "󰂯";
            format-off = "󰂲";
            on-click-middle = "${lib.getExe bluetoothToggle}";
            tooltip-format = "  {controller_alias}\t󰿀  {controller_address}\n󰂴  {num_connections} connected";
            tooltip-format-connected = "  {controller_alias}\t󰿀  {controller_address}\n󰂴  {num_connections} connected\n{device_enumerate}";
            tooltip-format-disabled = "󰂲  {controller_alias}\t󰿀  {controller_address}\n󰂳  {status}";
            tooltip-format-enumerate-connected = "󰂱  {device_alias}\t󰿀  {device_address}";
            tooltip-format-enumerate-connected-battery = "󰂱  {device_alias}\t󰿀  {device_address} (󰥉  {device_battery_percentage}󰏰)";
            tooltip-format-off = "󰂲  {controller_alias}\t󰿀  {controller_address}\n󰂳  {status}";
          };
          backlight = {
            # TODO: configure this to use the correct device
            device = "thinkpad_acpi";
            format = "<big>{icon}</big>";
            format-alt = "<big>{icon}</big> <small>{percent}󰏰</small>";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
            on-click-middle = "${pkgs.avizo}/bin/lightctl -d set 50";
            on-scroll-up = "${pkgs.avizo}/bin/lightctl -d up 2";
            on-scroll-down = "${pkgs.avizo}/bin/lightctl -d down 2";
            tooltip-format = "󰃠  {percent}󰏰";
          };
          power-profiles-daemon = {
            format = "<big>{icon}</big>";
            format-icons = {
              default = "󱐋";
              performance = "󰤇";
              balanced = "󰗑";
              power-saver = "󰴻";
            };
            tooltip-format = "󱐋  Power profile: {profile}\n󰒓  Driver: {driver}";
            #TODO: add power profile menu on middle click
          };
          cpu = {
            interval = 2;
            format = "<big>{icon}</big>";
            format-alt = "<big></big> <small>{usage}󱉸</small>";
            format-icons = [
              "󰫃"
              "󰫄"
              "󰫅"
              "󰫆"
              "󰫇"
              "󰫈"
            ];
            on-click-middle = "${pkgs.resources}/bin/resources --open-tab-id cpu";
          };
          temperature = {
            hwmon-path = "${hwmonPath}";
            critical-threshold = 90;
            format = "<big>{icon}</big>";
            format-alt = "<big>{icon}</big> <small>{temperatureC}󰔄</small>";
            format-critical = "<big></big> <small>{temperatureC}󰔄</small>";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
            tooltip-format = "󰔐  CPU {temperatureC}󰔄";
          };
          battery = {
            states = {
              good = 80;
              warning = 20;
              critical = 5;
            };
            format = "<big>{icon}</big>";
            format-alt = "<big>{icon}</big> <small>{capacity}󰏰</small>";
            format-charging = "󰂄";
            format-full = "󰁹";
            format-plugged = "󰚥";
            format-icons = [
              "󰂃"
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
            tooltip-format = "󱊣  {time} ({capacity}󰏰)";
            on-click-middle = "${pkgs.powersupply}/bin/powersupply";
          };
          "custom/session" = {
            format = "<big>󰐥</big>";
            on-click = "${lib.getExe pkgs.wlogout} --buttons-per-row 5 ${wlogoutMargins}";
            tooltip-format = "󰐥  Session Menu";
          };
        }
      ];
      systemd = {
        enable = true;
        target = "hyprland-session.target";
      };
    };
  };
}
