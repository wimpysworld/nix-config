{ hostname, lib, ... }:
{
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; {
    "net/launchpad/plank/docks/dock1" = {
      dock-items = [
        "brave-browser.dockitem"
        "Wavebox.dockitem"
        "org.telegram.desktop.dockitem"
        "discord.dockitem"
        "org.gnome.Fractal.dockitem"
        "org.squidowl.halloy.dockitem"
        "code.dockitem"
        "GitKraken.dockitem"
        "com.obsproject.Studio.dockitem"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>e";
      name = "File Manager";
      command = "io.elementary.files -n ~/";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>t";
      name = "Terminal";
      command = "alacritty";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Primary><Alt>t";
      name = "Terminal";
      command = "alacritty";
    };

    "org/gnome/desktop/background" =
      {
        picture-options = "zoom";
      }
      // lib.optionalAttrs (hostname == "phasma") {
        picture-uri = "file:///etc/backgrounds/Catppuccin-3440x1440.png";
        picture-uri-dark = "file:///etc/backgrounds/Catppuccin-3440x1440.png";
      }
      // lib.optionalAttrs (hostname == "sidious") {
        picture-uri = "file:///etc/backgrounds/Catppuccin-3840x2160.png";
        picture-uri-dark = "file:///etc/backgrounds/Catppuccin-3840x2160.png";
      }
      // lib.optionalAttrs (hostname == "tanis") {
        picture-uri = "file:///etc/backgrounds/Catppuccin-1920x1200.png";
        picture-uri-dark = "file:///etc/backgrounds/Catppuccin-1920x1200.png";
      }
      // lib.optionalAttrs (hostname == "vader") {
        picture-uri = "file:///etc/backgrounds/Catppuccin-2560x2880.png";
        picture-uri-dark = "file:///etc/backgrounds/Catppuccin-2560x2880.png";
      };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file://etc/backgrounds/Catppuccin-3840x2160.png";
    };

    "org/gnome/desktop/input-sources" = {
      xkb-options = [
        "grp:alt_shift_toggle"
        "caps:none"
      ];
    };

    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = mkInt32 8;
      workspace-names = [
        "Web"
        "Work"
        "Chat"
        "Code"
        "Term"
        "Cast"
        "Virt"
        "Fun"
      ];
    };

    "io/elementary/terminal/settings" = {
      unsafe-paste-alert = false;
    };

    "org/gnome/desktop/default/applications/terminal" = {
      exec = "alacritty";
      exec-arg = "--command";
    };
  };
}
