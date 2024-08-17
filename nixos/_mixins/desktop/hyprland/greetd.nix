{
  hostname,
  pkgs,
  username,
  ...
}:
{
  programs = {
    regreet = {
      enable = true;
      settings = {
        background = {
          path = "/etc/backgrounds/DeterminateColorway-1920x1080.png";
          # How the background image covers the screen if the aspect ratio doesn't match
          # Available values: "Fill", "Contain", "Cover", "ScaleDown"
          # Refer to: https://docs.gtk.org/gtk4/enum.ContentFit.html
          fit = "Cover";
        };
        GTK = {
          application_prefer_dark_theme = true;
          cursor_theme_name = "catppuccin-mocha-blue-cursors";
          font_name = "Work Sans 16";
          icon_theme_name = "Papirus-Dark";
          theme_name = "catppuccin-mocha-blue-standard+default";
        };
        commands = {
          reboot = [ "${pkgs.systemd}/bin/systemctl" "reboot" ];
          poweroff = [ "${pkgs.systemd}/bin/systemctl" "poweroff" ];
        };
        appearance = {
          # The message that initially displays on startup
          greeting_msg = "Welcome to ${hostname}!";
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
  security = {
    pam = {
      services = {
        # unlock gnome keyring automatically with greetd
        greetd.enableGnomeKeyring = true;
      };
    };
  };

  services = {
    greetd = {
      settings = {
        initial_session = {
          command = "${pkgs.unstable.hyprland}/bin/Hyprland > /dev/null 2>&1";
          user = "${username}";
        };
      };
      vt = 7;
    };
  };
}
