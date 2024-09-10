{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf isLinux {
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
        command = "nautilus -w ~/";
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

      "org/gnome/desktop/default/applications/terminal" = {
        exec = "alacritty";
        exec-arg = "--command";
      };

      "org/gnome/mutter" = {
        # Disable Mutter edge-tiling because tiling-assistant extension handles it
        edge-tiling = false;
      };

      "org/gnome/mutter/keybindings" = {
        # Disable Mutter toggle-tiled because tiling-assistant extension handles it
        toggle-tiled-left = mkEmptyArray type.string;
        toggle-tiled-right = mkEmptyArray type.string;
      };

      "org/gnome/shell" = {
        disabled-extensions = mkEmptyArray type.string;
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
          "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
          "dash-to-dock@micxgx.gmail.com"
          "emoji-copy@felipeftn"
          "freon@UshakovVasilii_Github.yahoo.com"
          "just-perfection-desktop@just-perfection"
          "logomenu@aryan_k"
          "start-overlay-in-application-view@Hex_cz"
          "tiling-assistant@leleat-on-github"
          "Vitals@CoreCoding.com"
          "wireless-hid@chlumskyvaclav.gmail.com"
          "wifiqrcode@glerro.pm.me"
          "workspace-switcher-manager@G-dH.github.com"
        ];
        favorite-apps = [
          "brave-browser.desktop"
          "Wavebox.desktop"
          "org.telegram.desktop.desktop"
          "discord.desktop"
          "org.gnome.Fractal.desktop"
          "org.squidowl.halloy.desktop"
          "code.desktop"
          "GitKraken.desktop"
          "com.obsproject.Studio.desktop"
        ];
      };

      "org/gnome/shell/extensions/auto-move-windows" = {
        application-list = [
          "brave-browser.desktop:1"
          "Wavebox.desktop:2"
          "discord.desktop:2"
          "org.telegram.desktop.desktop:3"
          "org.squidowl.halloy.desktop:3"
          "org.gnome.Fractal.desktop:3"
          "code.desktop:4"
          "GitKraken.desktop:4"
          "com.obsproject.Studio.desktop:6"
        ];
      };

      "org/gnome/shell/extensions/dash-to-dock" = {
        background-opacity = mkDouble 0.0;
        transparency-mode = "FIXED";
      };

      "org/gnome/shell/extensions/freon" = {
        hot-sensors = [ "__average__" ];
      };

      "org/gnome/shell/extensions/Logo-menu" = {
        menu-button-system-monitor = "gnome-usage";
        menu-button-terminal = "alacritty";
      };

      "org/gnome/shell/extensions/tiling-assistant" = {
        enable-advanced-experimental-features = true;
        show-layout-panel-indicator = true;
        single-screen-gap = mkInt32 10;
        window-gap = mkInt32 10;
        maximize-with-gap = true;
      };

      "org/gnome/shell/extensions/vitals" = {
        alphabetize = false;
        fixed-widths = true;
        include-static-info = false;
        menu-centered = true;
        monitor-cmd = "gnome-usage";
        network-speed-format = mkInt32 1;
        show-fan = false;
        show-temperature = false;
        show-voltage = false;
        update-time = mkInt32 2;
        use-higher-precision = false;
      };

      "org/gnome/desktop/wm/keybindings" = {
        # Disable maximise/unmaximise because tiling-assistant extension handles it
        maximize = mkEmptyArray type.string;
        unmaximize = mkEmptyArray type.string;
      };
    };
}
