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
      gnugrep
    ];
    text = ''
      if [[ "$(bluetoothctl show | grep -Po "Powered: \K(.+)$")" =~ no ]]; then
        bluetoothctl power on
        bluetoothctl discoverable on
      else
        bluetoothctl power off
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
  font-size: 20px;
  min-height: 0;
}

tooltip {
  background: @base;
  border: 1px solid @blue;
}

tooltip label {
  color: @text;
}

#waybar {
  background: transparent;
  color: @text;
  margin: 5px 5px;
}

#workspaces {
  border-radius: 1rem;
  margin: 5px;
  background-color: @base;
  margin-left: 0.5rem;
}

#workspaces button {
  color: @lavender;
  border-radius: 1rem;
  padding: 0.5rem 0.9rem;
}

#workspaces button.active {
  color: @sky;
}

#workspaces button:hover {
  color: @mauve;
}

#idle_inhibitor {
  border-radius: 1rem 0px 0px 1rem;
}

#idle_inhibitor.activated{
  color: @text;
}

#idle_inhibitor.deactivated{
  color: @sky;
}

#clock {
  border-radius: 0px 1rem 1rem 0px;
  color: @blue;
}

#tray {
  margin-right: 1rem;
  border-radius: 1rem;
}

#idle_inhibitor,
#clock,
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
  margin-left: 1rem;
}

#pulseaudio {
  color: @mauve;
}

#network {
  color: @sapphire;
}

#bluetooth {
  color: @blue;
}

#pulseaudio,
#network,
#bluetooth,
#backlight,
#power-profiles-daemon,
#temperature,
#battery {
  border-radius: 0;
}

#backlight {
  color: @yellow;
}

#power-profiles-daemon {
  color: @teal;
}

#temperature {
  color: @maroon;
}

#temperature.critical {
  color: @red;
}

#battery {
  color: @green;
  border-radius: 0px 1rem 1rem 0px;
  margin-right: 1rem;
}

#battery.charging {
  color: @green;
}

#battery.warning:not(.charging) {
  color: @red;
}

#custom-session {
  margin-right: 0.5rem;
  border-radius: 1rem 1rem 1rem 1rem;
  color: @red;
}
      '';
      settings = [{
        exclusive = true;
        layer = "top";
        position = "top";
        passthrough = false;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "idle_inhibitor" "clock" ];
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
          "persistent_workspaces" = {
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
          tooltip-format-activated = " Presentation mode: {status}";
          tooltip-format-deactivated = " Presentation mode: {status}";
        };
        clock = {
          format = "<small>{:%a, %d %b %R}</small>";
          format-alt = "<small>{:%H:%M}</small>";
          timezone = "Europe/London";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        tray = {
          icon-size = 22;
          spacing = 12;
        };
        wireplumber = {
          scroll-step = 5;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{volume}%</small>";
          format-muted = "";
          format-icons = {
            default = [ "" "" "" ];
          };
          max-volume =  100;
          on-click-middle = "${pkgs.avizo}/bin/volumectl toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -u up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -u down 2";
          tooltip-format = " {volume}% / {node_name}";
        };
        pulseaudio = {
          format = "<big>{format_source}</big>";
          format-alt = "<big>{format_source}</big> <small>{source_volume}%</small>";
          format-source = "";
          format-source-muted = "";
          on-click-middle = "${pkgs.avizo}/bin/volumectl -m toggle-mute";
          on-click-right = "${lib.getExe pkgs.pwvucontrol}";
          on-scroll-up = "${pkgs.avizo}/bin/volumectl -m up 2";
          on-scroll-down = "${pkgs.avizo}/bin/volumectl -m down 2";
          tooltip-format = " {source_volume}% / {desc}";
        };
        network = {
          format = "<big>{icon}</big>";
          format-alt = " <small>{bandwidthDownBits}</small>   <small>{bandwidthUpBits}</small>";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          format-linked = "";
          format-wifi = "";
          interval = 2;
          on-click-right = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          tooltip-format = " {ifname}\n󱦂 {ipaddr} via {gwaddr}\n {bandwidthDownBits}\t {bandwidthUpBits}";
          tooltip-format-wifi = " {essid} {signalStrength}%\n󱦂 {ipaddr} via {gwaddr}\n {bandwidthDownBits}\t {bandwidthUpBits}";
          tooltip-format-ethernet = "󰈀 {ifname}\n󱦂 {ipaddr} via {gwaddr})\n {bandwidthDownBits}\t {bandwidthUpBits}";
          tooltip-format-disconnected = "󰖪 Disconnected";
        };
        bluetooth = {
          format = "<big>{icon}</big>";
          format-connected = "󰂱";
          format-disabled = "󰂲";
          format-on = "󰂯";
          format-off = "󰂲";
          on-click-middle = "${lib.getExe bluetoothToggle}";
          on-click-right = "${lib.getExe pkgs.overskride}";
          tooltip-format = "󰂯 {controller_alias}\t{controller_address}\n{num_connections} connected";
          tooltip-format-connected = "󰂱 {controller_alias}\t{controller_address}\n{num_connections} connected\n{device_enumerate}";
          tooltip-format-disabled = "󰂲 {controller_alias}\t{controller_address}\n{status}";
          tooltip-format-enumerate-connected = "󰂱 {device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "󰂱 {device_alias}\t{device_address}\t{device_battery_percentage}%";
          tooltip-format-off = "󰂲 {controller_alias}\t{controller_address}\n{status}";
        };
        backlight = {
          device = "thinkpad_acpi";
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{percent}%</small>";
          format-icons = ["" "" "" "" "" "" "" "" ""];
          on-click-middle = "${pkgs.avizo}/bin/lightctl set 50";
          on-scroll-up = "${pkgs.avizo}/bin/lightctl up 2";
          on-scroll-down = "${pkgs.avizo}/bin/lightctl down 2";
          tooltip-format = " {percent}%";
        };
        power-profiles-daemon = {
          format = "<big>{icon}</big>";
          format-icons = {
            default = "";
            performance = "";
            balanced = "";
            power-saver = "";
          };
          tooltip-format = " Power profile: {profile}\n Driver: {driver}";
        };
        temperature = {
          thermal-zone = 0;
          critical-threshold = 80;
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{temperatureC}°C</small>";
          format-critical = " <small>{temperatureC}°C</small>";
          format-icons = ["" "" "" "" ""];
          tooltip-format = " CPU {temperatureC}°C";
        };
        battery = {
          states = {
            good = 80;
            warning = 20;
            critical = 5;
          };
          format = "<big>{icon}</big>";
          format-alt = "<big>{icon}</big> <small>{capacity}%</small>";
          format-charging = "󰂄";
          format-full = "󰁹";
          format-plugged = "";
          format-icons = [ "󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format = "󰁹 {time} ({capacity}%)";
        };
        "custom/session" = {
          format = "<big></big>";
          on-click = "${lib.getExe pkgs.wlogout} --buttons-per-row 5 --no-span";
          tooltip-format = " Session Menu";
        };
      }];
      systemd = {
        enable = true;
      };
    };
  };
}
