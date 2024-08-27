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
  margin: 5px 5px;
}

#workspaces {
  border-radius: 1rem;
  background-color: @base;
  margin: 5px;
  margin-left: 0.5rem;
}

#workspaces button {
  color: @lavender;
  border-radius: 1rem;
  padding: 0.5rem 0.9rem;
}

#workspaces button.active {
  color: @mauve;
}

#workspaces button:hover {
  color: @mauve;
}

#idle_inhibitor {
  border-radius: 1rem 0px 0px 1rem;
  color: @sky;
}

#clock {
  color: @blue;
  font-size: 16px;
}

#custom-swaync {
  border-radius: 0px 1rem 1rem 0px;
  color: @sky;
}

#idle_inhibitor,
#clock,
#custom-swaync {
  background-color: @base;
  padding: 0.5rem 0.7rem;
  margin: 5px 0;
}

#tray {
  margin-right: 1rem;
  border-radius: 1rem;
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
  padding: 0.5rem 0.9rem;
  margin: 5px 0;
}

#wireplumber {
  color: @mauve;
  border-radius: 1rem 0px 0px 1rem;
  font-family: Work Sans;
  font-size: 17px;
  margin-left: 1rem;
}

#pulseaudio {
  border-radius: 0;
  color: @mauve;
  font-family: Work Sans;
  font-size: 17px;
}

#network {
  border-radius: 0;
  color: @sapphire;
  font-family: Work Sans;
  font-size: 18px;
}

#bluetooth {
  border-radius: 0;
  color: @blue;
}

#backlight {
  border-radius: 0;
  color: @yellow;
  font-family: Work Sans;
  font-size: 18px;
}

#power-profiles-daemon {
  border-radius: 0;
  color: @teal;
  font-size: 26px;
}

#temperature {
  border-radius: 0;
  color: @maroon;
  font-family: Work Sans;
  font-size: 18px;
}

#temperature.critical {
  color: @red;
}

#battery {
  border-radius: 0px 1rem 1rem 0px;
  color: @green;
  font-family: Work Sans;
  font-size: 18px;
  margin-right: 1rem;
}

#battery.charging {
  color: @green;
}

#battery.warning:not(.charging) {
  color: @red;
}

#custom-session {
  border-radius: 1rem 1rem 1rem 1rem;
  color: @red;
  margin-right: 0.5rem;
}
      '';
      settings = [{
        exclusive = true;
        layer = "top";
        position = "top";
        passthrough = false;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "idle_inhibitor" "clock" "custom/swaync" ];
        modules-right = [ "tray" "wireplumber" "pulseaudio" "network" "bluetooth" "backlight" "power-profiles-daemon" "temperature" "battery" "custom/session" ];
        "hyprland/workspaces" = {
          active-only = false;
          format = "<big>{icon}</big>";
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            "6" = "";
            "7" = "";
            "8" = "";
          };
          persistent_workspaces = {
            "1" = [];
            "2" = [];
            "3" = [];
            "4" = [];
            "5" = [];
            "6" = [];
            "7" = [];
            "8" = [];
          };
          on-click = "activate";
        };
        idle_inhibitor = {
          format = "<big>{icon}</big>";
          format-icons = {
            activated = "";
            deactivated = "";
          };
          start-activated = false;
          tooltip-format-activated = "  Presentation mode {status}";
          tooltip-format-deactivated = "  Presentation mode {status}";
        };
        clock = {
          format = "<big>{:%H:%M}</big>";
          format-alt = "{:%a, %d %b %R}";
          timezone = "Europe/London";
          tooltip-format = "<big>{:%a, %d %b}</big>\n<tt>{calendar}</tt>";
        };
        #https://haseebmajid.dev/posts/2024-03-15-til-how-to-get-swaync-to-play-nice-with-waybar/
        "custom/swaync" = {
          format = "<big>{icon}</big>";
          format-icons = {
            none = "<sup> </sup>";
            notification = "<span foreground='#fab387'><sup></sup></span>";
            dnd-none = "󰂛<sup> </sup>";
            dnd-notification = "󰂛<span foreground='#f2cdcd'><sup></sup></span>";
            inhibited-none = "<sup> </sup>";
            inhibited-notification = "<span foreground='#f2cdcd'><sup></sup></span>";
            dnd-inhibited-none = "󰂛<sup> </sup>";
            dnd-inhibited-notification = "󰂛<span foreground='#f2cdcd'><sup></sup></span>";
          };
          max-length = 3;
          return-type = "json";
          escape = true;
          exec-if = "which ${pkgs.swaynotificationcenter}/bin/swaync-client";
          exec = "${pkgs.swaynotificationcenter}/bin/swaync-client --subscribe-waybar";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";
          on-click-middle = "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-dnd --skip-wait";
          tooltip-format = "  {} notifications";
        };
        tray = {
          icon-size = 22;
          spacing = 12;
        };
        wireplumber = {
          scroll-step = 5;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big><tt>  <small>{volume}%</small></tt>";
          format-muted = "";
          format-icons = {
            default = [ "" "" "" ];
          };
          max-volume =  100;
          on-click-middle = "${pkgs.avizo}/bin/volumectl toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -u up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -u down 2";
          tooltip-format = "  {volume}% / {node_name}";
        };
        pulseaudio = {
          format = "<big>{format_source}</big>";
          format-alt = "<big>{format_source}</big><tt> <small>{source_volume}%</small></tt>";
          format-source = "";
          format-source-muted = "";
          on-click-middle = "${pkgs.avizo}/bin/volumectl -m toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -m up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -m down 2";
          tooltip-format = "  {source_volume}% / {desc}";
        };
        network = {
          format = "<big>{icon}</big>";
          format-alt = "<tt> <small>{bandwidthDownBits}</small> </tt><tt> <small>{bandwidthUpBits}</small></tt>";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          format-linked = "";
          format-wifi = "";
          interval = 2;
          on-click-right = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          tooltip-format = "  {ifname}\n󱦂  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-wifi = "  {essid} {signalStrength}%\n󱦂  {ipaddr} via {gwaddr}\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-ethernet = "󰈀  {ifname}\n󱦂  {ipaddr} via {gwaddr})\n  {bandwidthDownBits}\t  {bandwidthUpBits}";
          tooltip-format-disconnected = "󰖪  disconnected";
        };
        bluetooth = {
          format = "<big>{icon}</big>";
          format-connected = "󰂱";
          format-disabled = "󰂲";
          format-on = "󰂯";
          format-off = "󰂲";
          on-click-middle = "${lib.getExe bluetoothToggle}";
          on-click-right = "${lib.getExe pkgs.overskride}";
          tooltip-format = "󰂯  {controller_alias}\t{controller_address}\n{num_connections} connected";
          tooltip-format-connected = "󰂱  {controller_alias}\t{controller_address}\n{num_connections} connected\n{device_enumerate}";
          tooltip-format-disabled = "󰂲  {controller_alias}\t{controller_address}\n{status}";
          tooltip-format-enumerate-connected = "󰂱  {device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "󰂱  {device_alias}\t{device_address}\t{device_battery_percentage}%";
          tooltip-format-off = "󰂲  {controller_alias}\t{controller_address}\n{status}";
        };
        backlight = {
          device = "thinkpad_acpi";
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big><tt> <small>{percent}%</small></tt>";
          format-icons = ["" "" "" "" "" "" "" "" ""];
          on-click-middle = "${pkgs.avizo}/bin/lightctl set 50";
          on-scroll-up = "${pkgs.avizo}/bin/lightctl up 2";
          on-scroll-down = "${pkgs.avizo}/bin/lightctl down 2";
          tooltip-format = "  {percent}%";
        };
        power-profiles-daemon = {
          format = "<big>{icon}</big>";
          format-icons = {
            default = "";
            performance = "";
            balanced = "";
            power-saver = "";
          };
          tooltip-format = "  Power profile: {profile}\n  Driver: {driver}";
        };
        temperature = {
          thermal-zone = 0;
          critical-threshold = 80;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big><tt> <small>{temperatureC}°C</small></tt>";
          format-critical = "<tt> <small>{temperatureC}°C</small></tt>";
          format-icons = ["" "" "" "" "" "" "" ""];
          tooltip-format = "  CPU {temperatureC}°C";
        };
        battery = {
          states = {
            good = 80;
            warning = 20;
            critical = 5;
          };
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big><tt> <small>{capacity}%</small></tt>";
          format-charging = "󰂄";
          format-full = "󰁹";
          format-plugged = "";
          format-icons = [ "󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format = "󰁹  {time} ({capacity}%)";
        };
        "custom/session" = {
          format = "<big></big>";
          on-click = "${lib.getExe pkgs.wlogout} --buttons-per-row 5 --no-span";
          tooltip-format = "  Session Menu";
        };
      }];
      systemd = {
        enable = true;
      };
    };
  };
}
