{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
  # The pills carry the alpha on the background colour, so text stays opaque.
  pillColor = "alpha(@base, ${toString palette.alpha.surface})";
  # Every module hovers to mantle, the clearest change against the base pills.
  hoverColor = "alpha(@mantle, ${toString palette.alpha.surface})";
  inherit (host) display;
  outputDisplay = display.primaryOutput;
  bluetoothToggle = pkgs.writeShellApplication {
    name = "bluetooth-toggle";
    runtimeInputs = with pkgs; [
      bluez
      fyi
      gawk
      gnugrep
    ];
    text = builtins.readFile ./bluetooth-toggle.sh;
  };
  virtualcamCheck = pkgs.writeShellApplication {
    name = "virtualcam-check";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
    ];
    text = builtins.readFile ./virtualcam-check.sh;
  };
  virtualcamToggle = pkgs.writeShellApplication {
    name = "virtualcam-toggle";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      fyi
    ];
    text = builtins.readFile ./virtualcam-toggle.sh;
  };
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [
        host.desktop
      ] null (import ../../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
  swayosdClient = lib.getExe' pkgs.swayosd "swayosd-client";
  # SwayOSD does not unmute on a volume change, so unmute the output first.
  unmuteOutput = "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ 0";
  workspaceModule = compositor.waybar.workspaceModule or null;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  catppuccin = {
    waybar.enable = config.programs.waybar.enable;
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
          background: alpha(@mantle, ${toString palette.alpha.surfaceStrong});
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
          background-color: ${pillColor};
          border-radius: 0.75rem;
          color: @sapphire;
          margin: 5px 0 0 0;
          margin-left: 0.5rem;
          padding: 0.25rem 0.75rem;
        }

        #custom-launcher:hover {
          background-color: ${hoverColor};
        }

        #workspaces {
          border-radius: 0.75rem;
          background-color: ${pillColor};
          margin: 5px 0 0 0.5rem;
          margin-left: 1rem;
        }

        #workspaces button,
        #workspaces label.module {
          border-radius: 0.75rem;
          color: @mauve;
          padding: 0.25rem 0.75rem;
        }

        ${lib.optionalString (host.desktop == "wayfire") ''
          #workspaces button {
            padding: 0.25rem;
          }
        ''}

        #workspaces button.active,
        #workspaces button.focused,
        #workspaces label.module.active {
          color: @peach;
        }

        #workspaces button:hover,
        #workspaces label.module:hover {
          background-color: ${hoverColor};
        }

        #workspaces button.urgent,
        #workspaces label.module.urgent {
          color: @red;
        }

        #idle_inhibitor {
          border-radius: 0.75rem 0 0 0.75rem;
          color: @flamingo;
        }

        #clock {
          color: @rosewater;
          font-size: 16px;
        }

        #custom-swaync {
          border-radius: 0 0.75rem 0.75rem 0;
          color: @flamingo;
        }

        #idle_inhibitor,
        #clock,
        #custom-swaync {
          background-color: ${pillColor};
          margin: 5px 0 0 0;
          padding: 0.25rem 0.75rem;
        }

        #idle_inhibitor:hover,
        #clock:hover,
        #custom-swaync:hover {
          background-color: ${hoverColor};
        }

        #custom-recording {
          background-color: ${pillColor};
          border-radius: 0.75rem;
          color: @text;
          margin: 5px 0 0 0.5rem;
          padding: 0.25rem 0.75rem;
        }

        #custom-recording:hover {
          background-color: ${hoverColor};
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
        #battery,
        #backlight,
        #cpu,
        #temperature,
        #power-profiles-daemon,
        #custom-session {
          background-color: ${pillColor};
          margin: 5px 0 0 0;
          padding: 0.25rem 0.75rem;
        }

        #custom-virtualcam:hover,
        #wireplumber:hover,
        #pulseaudio.input:hover,
        #bluetooth:hover,
        #network:hover,
        #battery:hover,
        #backlight:hover,
        #cpu:hover,
        #temperature:hover,
        #power-profiles-daemon:hover,
        #custom-session:hover {
          background-color: ${hoverColor};
        }


        #wireplumber {
          border-radius: 0.75rem 0 0 0.75rem;
          color: @mauve;
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
        (
          {
            exclusive = true;
            margin-bottom = lib.mkIf (host.desktop == "wayfire") 5;
            output = outputDisplay;
            layer = "bottom";
            position = "top";
            modules-left = [
              "custom/launcher"
            ]
            ++ lib.optional (workspaceModule != null) workspaceModule
            # The recording indicator shows only while a recording runs.
            ++ [ "custom/recording" ];
            modules-center = [
              "idle_inhibitor"
              "clock"
              "custom/swaync"
            ];
            modules-right = [
              "tray"
              "wireplumber"
              "pulseaudio#input"
            ]
            ++ lib.optional (noughtyLib.hostHasTag "pci-hdmi-capture") "custom/virtualcam"
            ++ [
              "bluetooth"
              "network"
              "battery"
              "backlight"
              "cpu"
              "temperature"
              "power-profiles-daemon"
              "custom/session"
            ];
            "custom/launcher" = {
              format = "<big>󱄅</big>";
              on-click = "${pkgs.rofi}/bin/rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun";
              on-click-right = "fuzzel-session-menu";
              tooltip-format = "  Applications Menu";
            };
            idle_inhibitor = {
              format = "<big>{icon}</big>";
              format-icons = {
                activated = "<span foreground='${palette.getColor "pink"}'>󰅶</span>";
                deactivated = "󰾪";
              };
              start-activated = false;
              tooltip-format-activated = "󰅶  Caffeination {status}";
              tooltip-format-deactivated = "󰾪  Caffeination {status}";
            };
            clock = {
              actions = {
                on-click = "shift_down";
                on-click-right = "shift_up";
              };
              calendar = {
                mode = "year";
                mode-mon-col = 3;
                on-scroll = 1;
                weeks-pos = "right";
                format = {
                  days = "<span color='${palette.getColor "text"}'><b>{}</b></span>";
                  months = "<span color='${palette.getColor "blue"}'><b>{}</b></span>";
                  weeks = "<span color='${palette.getColor "sapphire"}'><b>󱦰{}</b></span>";
                  weekdays = "<span color='${palette.getColor "peach"}'><b>{}</b></span>";
                  today = "<span color='${palette.getColor "red"}'><b>{}</b></span>";
                };
              };
              on-click-middle = "${pkgs.gnome-clocks}/bin/gnome-clocks";
              format = "{:%b/%d %H:%M}";
              interval = 60;
              tooltip-format = "<tt><small>{calendar}</small></tt>";
            };
            #https://haseebmajid.dev/posts/2024-03-15-til-how-to-get-swaync-to-play-nice-with-waybar/
            "custom/swaync" = {
              format = "<big>{icon}</big>";
              format-icons = {
                none = "";
                notification = "<span foreground='${palette.getColor "pink"}'>󱅫</span>";
                dnd-none = "󰂠";
                dnd-notification = "󱅫";
                inhibited-none = "";
                inhibited-notification = "<span foreground='${palette.getColor "pink"}'>󰅸</span>";
                dnd-inhibited-none = "󰪓";
                dnd-inhibited-notification = "󰅸";
              };
              max-length = 3;
              return-type = "json";
              escape = true;
              exec-if = "which ${pkgs.swaynotificationcenter}/bin/swaync-client";
              exec = "${pkgs.swaynotificationcenter}/bin/swaync-client --subscribe-waybar";
              on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";
              tooltip-format = "󰵚  {} notification(s)";
            };
            # fuzzel-capture prints the elapsed time while a screen recording
            # runs and sends SIGRTMIN+9 when one starts or stops. The module
            # hides when the state file is absent or the output is empty.
            "custom/recording" = {
              format = "<big><span foreground='${palette.getColor "red"}'>󰑊</span></big> <small>{}</small>";
              exec-if = "test -e \"$XDG_RUNTIME_DIR/fuzzel-capture-recording.state\"";
              exec = "fuzzel-capture status";
              interval = 1;
              signal = 9;
              on-click = "fuzzel-capture stop";
              tooltip-format = "󰑊  Screen recording. Click to stop.";
            };
            tray = {
              icon-size = 22;
              spacing = 12;
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
              on-click-middle = "${swayosdClient} --output-volume mute-toggle";
              on-scroll-up = "${unmuteOutput}; ${swayosdClient} --output-volume +2";
              on-scroll-down = "${unmuteOutput}; ${swayosdClient} --output-volume -2";
              tooltip-format = "󰓃  {volume}󰏰\n󰒓  {node_name}";
            };
            "pulseaudio#input" = {
              format = "<big>{format_source}</big>";
              format-alt = "<big>{format_source}</big> <small>{source_volume}󰏰</small>";
              format-source = "󰍬";
              format-source-muted = "󰍭";
              on-click-middle = "${swayosdClient} --input-volume mute-toggle";
              on-scroll-up = "${swayosdClient} --input-volume +2";
              on-scroll-down = "${swayosdClient} --input-volume -2";
              tooltip-format = "  {source_volume}󰏰\n󰒓  {desc}";
              ignored-sinks = [
                "INZONE Buds Analog Stereo"
              ];
            };
            "custom/virtualcam" = {
              format = "<big>{}</big>";
              exec = "${lib.getExe virtualcamCheck}";
              on-click-middle = "${lib.getExe virtualcamToggle}";
              interval = 1;
              max-length = 2;
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
            network = {
              format = "<big>{icon}</big>";
              format-alt = " <small>{bandwidthDownBits}</small>  <small>{bandwidthUpBits}</small>";
              format-ethernet = "󰈀";
              format-disconnected = "󰲜";
              format-linked = "";
              format-wifi = "󰖩";
              interval = 2;
              tooltip-format = "  {ifname}\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
              tooltip-format-wifi = "󱛁  {essid} \n󰒢  {signalStrength}󰏰\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
              tooltip-format-ethernet = "󰈀  {ifname}\n󰩠  {ipaddr} via {gwaddr})\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
              tooltip-format-disconnected = "󰲜  disconnected";
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
              on-click-middle = "${swayosdClient} --brightness 50";
              on-scroll-up = "${swayosdClient} --brightness +2";
              on-scroll-down = "${swayosdClient} --brightness -2";
              tooltip-format = "󰃠  {percent}󰏰";
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
              hwmon-path-abs = [
                "/sys/devices/platform/coretemp.0/hwmon"
                "/sys/devices/pci0000:00/0000:00:18.3/hwmon"
              ];
              input-filename = "temp1_input";
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
              on-click = "wleave-session";
              tooltip-format = "󰐥  Session Menu";
            };
          }
          // lib.optionalAttrs (workspaceModule != null) {
            ${workspaceModule} = compositor.waybar.workspaceSettings;
          }
          // config.compositor.waybar.modules
        )
      ];
      systemd = {
        enable = compositor != null;
        targets = [ sessionTarget ];
      };
    };
  };
}
