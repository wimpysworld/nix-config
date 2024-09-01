{ hostname, pkgs, ... }:
let
  wallpaperResolution = if hostname == "vader" then "2560x2880" else "1920x1080";
  # Vader and Phasma have dual GPUs; AMD for graphics and NVIDIA for compute
  defaultSession = if (hostname == "vader" || hostname == "phasma") then
    "env WLR_DRM_DEVICES=/dev/dri/card1 ${pkgs.sway}/bin/sway --config /etc/greetd/regreet-sway --unsupported-gpu"
  else
    "${pkgs.sway}/bin/sway --config /etc/greetd/regreet-sway";
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
      output * bg /etc/backgrounds/DeterminateColorway-${wallpaperResolution}.png fill
      seat seat0 xcursor_theme catppuccin-mocha-blue-cursors 48
      xwayland disable
      exec "${pkgs.greetd.regreet}/bin/regreet; ${pkgs.sway}/bin/swaymsg exit"
    '';
  };
  programs = {
    regreet = {
      enable = true;
      settings = {
        appearance = {
          greeting_msg = "This is ${hostname}!";
        };
        background = {
          path = "/etc/backgrounds/DeterminateColorway-${wallpaperResolution}.png";
          # How the background image covers the screen if the aspect ratio doesn't match
          # Available values: "Fill", "Contain", "Cover", "ScaleDown"
          # Refer to: https://docs.gtk.org/gtk4/enum.ContentFit.html
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
          theme_name = "catppuccin-mocha-blue-standard+default";
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
        #   name = "catppuccin-mocha-blue-standard+default";
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
        command = defaultSession;
        user = "greeter";
      };
    };
    vt = 7;
  };
}
