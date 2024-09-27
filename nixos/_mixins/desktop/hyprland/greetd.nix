{ config, hostname, lib, pkgs, username, ... }:
let
  hyprLaunch = pkgs.writeShellScriptBin "hypr-launch" ''
    ${pkgs.hyprland}/bin/Hyprland $@ &>/dev/null
    # Correctly clean up the session
    ${pkgs.hyprland}/bin/hyprctl dispatch exit
    systemctl --user --machine=${username}@.host stop dbus-broker
    systemctl --user --machine=${username}@.host stop hyprland-session.target
  '';
  regreetSway = pkgs.writeShellScriptBin "regreet-sway" ''
    # Check if a GPU is NVIDIA
    function is_nvidia() {
        local card=$1
        if [ -f "/sys/class/drm/$card/device/vendor" ]; then
            vendor=$(cat "/sys/class/drm/$card/device/vendor")
            # NVIDIA vendor ID is 0x10de
            if [ "$vendor" = "0x10de" ]; then
                # It is NVIDIA
                return 0
            fi
        fi
        # It is not NVIDIA
        return 1
    }
    REGREET_SWAY="${pkgs.sway}/bin/sway --config /etc/greetd/regreet-sway"
    # Prevent Sway from starting on NVIDIA GPUs; they are for compute only
    NVIDIA_MODULE_COUNT=$(lsmod | grep -w ^nvidia | wc -l)
    if [ $NVIDIA_MODULE_COUNT -gt 0 ]; then
      # Iterate through GPU devices
      for gpu in /dev/dri/card*; do
        # Extract the card name
        card=$(basename "$gpu")
        # Check if the GPU is not NVIDIA
        if ! is_nvidia "$card"; then
          export WLR_DRM_DEVICES=$gpu
        fi
      done
      REGREET_SWAY+=" --unsupported-gpu"
    fi
    $REGREET_SWAY &>/dev/null
  '';

  wallpaperResolution = if hostname == "vader" then
    "2560x2880"
  else if hostname == "phasma" then
    "3440x1440"
  else if hostname == "tanis" then
    "1920x1200"
  else "1920x1080";

  wallpapers = if hostname == "vader" then
    ''
    output DP-1 bg /etc/backgrounds/Catppuccin-2560x2880.png fill
    output DP-2 bg /etc/backgrounds/Colorway-2560x2880.png fill
    output DP-3 bg /etc/backgrounds/Colorway-1920x1080.png fill
    ''
  else if hostname == "phasma" then
    ''
    output DP-1 bg /etc/backgrounds/Catppuccin-3440x1440.png fill
    output HDMI-A-1 bg /etc/backgrounds/Colorway-2560x1600.png fill
    output DP-2 bg /etc/backgrounds/Colorway-1920x1080.png fill
    ''
  else if hostname == "tanis" then
    ''
    output eDP-1 bg /etc/backgrounds/Catppuccin-1920x1200.png fill
    ''
  else
    ''output * bg /etc/backgrounds/Catppuccin-1920x1080.png fill'';
in
{
  # Use a minimal Sway to run regreet
  environment = {
    etc."greetd/regreet-sway".text = ''
      input type:touchpad {
        tap enabled
        natural_scroll enabled
      }
      output * scale 1
      output * bg #1E1E2D solid_color
      ${wallpapers}
      seat seat0 xcursor_theme catppuccin-mocha-blue-cursors 48
      xwayland disable
      exec "${pkgs.greetd.regreet}/bin/regreet; ${pkgs.sway}/bin/swaymsg exit"
    '';
    systemPackages = [
      hyprLaunch
      regreetSway
    ];
  };
  programs = {
    regreet = {
      enable = true;
      settings = {
        appearance = {
          greeting_msg = "This is ${hostname}!";
        };
        # https://docs.gtk.org/gtk4/enum.ContentFit.html
        background = {
          path = "/etc/backgrounds/Catppuccin-${wallpaperResolution}.png";
          fit = "Cover";
        };
        commands = {
          reboot = [
            "${pkgs.systemd}/bin/systemctl"
            "reboot"
          ];
          poweroff = [
            "${pkgs.systemd}/bin/systemctl"
            "poweroff"
          ];
        };
        GTK = {
          application_prefer_dark_theme = true;
          cursor_theme_name = "catppuccin-mocha-blue-cursors";
          font_name = "Work Sans 16";
          icon_theme_name = "Papirus-Dark";
          theme_name = "catppuccin-mocha-blue-standard";
        };
        # cursorTheme = {
        #   name = "catppuccin-mocha-blue-cursors";
        #   package = pkgs.catppuccin-cursors.mochaBlue;
        # };
        # font = {
        #   name = "Work Sans";
        #   package = pkgs.work-sans;
        #   size = 24;
        # };
        # iconTheme = {
        #   name = "Papirus-Dark";
        #   package = pkgs.catppuccin-papirus-folders.override {
        #     flavor = "mocha";
        #     accent = "blue";
        #   };
        # };
        # theme = {
        #   name = "catppuccin-mocha-blue-standard";
        #   package = pkgs.catppuccin-gtk.override {
        #     accents = [ "blue" ];
        #     size = "standard";
        #     variant = "mocha";
        #   };
        # };
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "regreet-sway";
        user = "greeter";
      };
    };
    vt = 7;
  };
}
