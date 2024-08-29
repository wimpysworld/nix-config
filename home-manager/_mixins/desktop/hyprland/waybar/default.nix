{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  bluetoothToggle = pkgs.writeShellApplication {
    name = "bluetooth-toggle";
    runtimeInputs = with pkgs; [
      bluez
      gawk
      gnugrep
    ];
    text = ''
      state=$(bluetoothctl show | grep 'Powered:' | awk '{ print $2 }')
      if [[ $state == 'yes' ]]; then
        bluetoothctl discoverable off
        bluetoothctl power off
      else
        bluetoothctl power on
        bluetoothctl discoverable on
      fi
    '';
  };
in
{
  programs = {
    waybar = {
      enable = true;
      catppuccin.enable = true;
      style = ''
* {
  font-family: FiraCode Nerd Font Mono;
  font-size: 22px;
  min-height: 0;
}

tooltip {
  background: @base;
  opacity: 0.9;
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

#workspaces {
  border-radius: 0.75rem;
  background-color: @base;
  margin: 5px 0 0 0.5rem;
}

#workspaces button {
  border-radius: 0.75rem;
  color: @lavender;
  padding: 0.25rem 0.75rem;
}

#workspaces button.active {
  color: @mauve;
}

#workspaces button:hover {
  background-color: @mantle;
}

#idle_inhibitor {
  border-radius: 0.75rem 0 0 0.75rem;
  color: @sky;
}

#clock {
  color: @blue;
  font-size: 16px;
}

#custom-swaync {
  border-radius: 0 0.75rem 0.75rem 0;
  color: @sky;
}

#idle_inhibitor,
#clock,
#custom-swaync {
  background-color: @base;
  margin: 5px 0 0 0;
  padding: 0.25rem 0.75rem;
}

#idle_inhibitor:hover,
#clock:hover,
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
#wireplumber,
#pulseaudio,
#network,
#bluetooth,
#backlight,
#power-profiles-daemon,
#temperature,
#battery,
#custom-session {
  background-color: @base;
  margin: 5px 0 0 0;
  padding: 0.25rem 0.75rem;
}

#wireplumber:hover,
#pulseaudio:hover,
#network:hover,
#bluetooth:hover,
#backlight:hover,
#power-profiles-daemon:hover,
#temperature:hover,
#battery:hover,
#custom-session:hover {
  background-color: #242536;
}

#wireplumber {
  color: @mauve;
  border-radius: 0.75rem 0 0 0.75rem;
  margin-left: 1rem;
}

#pulseaudio {
  border-radius: 0;
  color: @mauve;
}

#network {
  border-radius: 0;
  color: @sapphire;
}

#bluetooth {
  border-radius: 0;
  color: @blue;
}

#backlight {
  border-radius: 0;
  color: @yellow;
}

#power-profiles-daemon {
  border-radius: 0;
  color: @teal;
  font-size: 25px;
}

#temperature {
  border-radius: 0;
  color: @maroon;
}

#temperature.critical {
  color: @red;
}

#battery {
  border-radius: 0 0.75rem 0.75rem 0;
  color: @green;
  margin-right: 1rem;
}

#battery.charging {
  color: @green;
}

#battery.warning:not(.charging) {
  color: @red;
}

#custom-session {
  border-radius: 0.75rem;
  color: @red;
  margin-right: 0.5rem;
}
      '';
      settings = [{
        exclusive = true;
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "idle_inhibitor" "clock" "custom/swaync" ];
        modules-right = [ "tray" "wireplumber" "pulseaudio" "network" "bluetooth" "backlight" "power-profiles-daemon" "temperature" "battery" "custom/session" ];
        "hyprland/workspaces" = {
          active-only = false;
          all-outputs = true;
          format = "<big>{icon}</big>";
          format-icons = {
            "1" = "󰖟";
            "2" = "󱒔";
            "3" = "󰭹";
            "4" = "󰅴";
            "5" = "󱆃";
            "6" = "󰡨";
            "7" = "󰦔";
            "8" = "󰺵";
          };
          persistent_workspaces = {
            # TODO: On desktops workstations, only put workspace 6 (Cast) on the dummy output
            # https://github.com/Alexays/Waybar/wiki/Module:-Hyprland#persistent-workspaces
            "*" = 8;
          };
          on-click = "activate";
        };
        idle_inhibitor = {
          format = "<big>{icon}</big>";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
          start-activated = false;
          tooltip-format-activated = "󰅶  Caffeination {status}";
          tooltip-format-deactivated = "󰾪  Caffeination {status}";
        };
        clock = {
          actions = {
            on-click = "shift_down";
            on-click-middle = "shift_reset";
            on-click-right = "shift_up";
          };
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            on-scroll = 1;
            weeks-pos = "right";
            format = {
              days   = "<span color='#cdd6f4'><b>{}</b></span>";
              months = "<span color='#89b4fa'><b>{}</b></span>";
              weeks  = "<span color='#74c7ec'><b>󱦰{}</b></span>";
              weekdays = "<span color='#fab387'><b>{}</b></span>";
              today  = "<span color='#f38ba8'><b>{}</b></span>";
            };
          };
          format = "<big>{:%H:%M}</big>";
          format-alt = "{:%a, %d %b %R}";
          interval = 60;
          timezone = "Europe/London";
          #timezones = [ "Europe/London" "Europe/Amsterdam" "America/Boston" "America/Los_Angeles" "Africa/Lagos" ];
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };
        #https://haseebmajid.dev/posts/2024-03-15-til-how-to-get-swaync-to-play-nice-with-waybar/
        "custom/swaync" = {
          format = "<big>{icon}</big>";
          format-icons = {
            none = "";
            notification = "<span foreground='#fab387'>󱅫</span>";
            dnd-none = "󰂠";
            dnd-notification = "󰂞";
            inhibited-none = "";
            inhibited-notification = "<span foreground='#f2cdcd'>󰅸</span>";
            dnd-inhibited-none = "󰪓";
            dnd-inhibited-notification = "󰂟";
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
        wireplumber = {
          scroll-step = 5;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{volume}󰏰</small>";
          format-muted = "󰖁";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          max-volume =  100;
          on-click-middle = "${pkgs.avizo}/bin/volumectl toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -u up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -u down 2";
          tooltip-format = "󰓃  {volume}󰏰\n󰒓  {node_name}";
        };
        pulseaudio = {
          format = "<big>{format_source}</big>";
          format-alt = "<big>{format_source}</big> <small>{source_volume}󰏰</small>";
          format-source = "󰍰";
          format-source-muted = "󰍱";
          on-click-middle = "${pkgs.avizo}/bin/volumectl -m toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -m up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -m down 2";
          tooltip-format = "  {source_volume}󰏰\n󰒓  {desc}";
        };
        network = {
          format = "<big>{icon}</big>";
          format-alt = " <small>{bandwidthDownBits}</small>  <small>{bandwidthUpBits}</small>";
          format-ethernet = "󰈀";
          format-disconnected = "󱚵";
          format-linked = "";
          format-wifi = "󰖩";
          interval = 2;
          on-click-right = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          tooltip-format = "  {ifname}\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-wifi = "󱛁  {essid} \n󰒢  {signalStrength}󰏰\n󰩠  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-ethernet = "󰈀  {ifname}\n󰩠  {ipaddr} via {gwaddr})\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-disconnected = "󱚵  disconnected";
        };
        bluetooth = {
          format = "<big>{icon}</big>";
          format-connected = "󰂱";
          format-disabled = "󰂲";
          format-on = "󰂯";
          format-off = "󰂲";
          on-click-middle = "${lib.getExe bluetoothToggle}";
          on-click-right = "${lib.getExe pkgs.overskride}";
          tooltip-format = "  {controller_alias}\n󰿀  {controller_address}\n󰂴  {num_connections} connected";
          tooltip-format-connected = "󰂱  {controller_alias}\n󰿀  {controller_address}\n󰂴  {num_connections} connected\n{device_enumerate}";
          tooltip-format-disabled = "󰂲  {controller_alias}\n󰿀  {controller_address}\n󰂳  {status}";
          tooltip-format-enumerate-connected = "󰂱  {device_alias}\n󰿀  {device_address}";
          tooltip-format-enumerate-connected-battery = "󰂱  {device_alias}\t󰿀  {device_address}\n󰥉  {device_battery_percentage}󰏰";
          tooltip-format-off = "󰂲  {controller_alias}\n󰿀  {controller_address}\n󰂳  {status}";
        };
        backlight = {
          device = "thinkpad_acpi";
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{percent}󰏰</small>";
          format-icons = ["" "" "" "" "" "" "" "" ""];
          on-click-middle = "${pkgs.avizo}/bin/lightctl set 50";
          on-scroll-up = "${pkgs.avizo}/bin/lightctl up 2";
          on-scroll-down = "${pkgs.avizo}/bin/lightctl down 2";
          tooltip-format = "󰃠  {percent}󰏰";
        };
        power-profiles-daemon = {
          format = "<big>{icon}</big>";
          format-icons = {
            default = "";
            performance = "󰤇";
            balanced = "󰗑";
            power-saver = "󰴻";
          };
          tooltip-format = "  Power profile: {profile}\n󰒓  Driver: {driver}";
        };
        temperature = {
          thermal-zone = 0;
          critical-threshold = 80;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{temperatureC}󰔄</small>";
          format-critical = "<big>󰸁</big> <small>{temperatureC}󰔄</small>";
          format-icons = [ "" "󱃃" "󱃃" "󰔏" "󰔏" "󰔏" "󱃂" ];
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
          format-icons = [ "󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format = "󱊣  {time} ({capacity}󰏰)";
        };
        "custom/session" = {
          format = "<big>󰐥</big>";
          on-click = "${lib.getExe pkgs.wlogout} --buttons-per-row 5 --no-span";
          tooltip-format = "󰐥  Session Menu";
        };
      }];
      systemd = {
        enable = true;
      };
    };
  };
}
