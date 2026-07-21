{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  # Get a colour as a hexadecimal string.
  getColor = colorName: catppuccinPalette.getColor colorName;
in
{
  imports = [
    ./alacritty.nix
    ./contour.nix
    ./foot.nix
    ./ghostty.nix
    ./kitty.nix
    ./mlterm.nix
    ./rio.nix
    ./wezterm.nix
  ];

  config = lib.mkIf host.is.workstation {

    # User specific dconf terminal-related settings. Nautilus is only installed
    # on workstations, so gate this setting accordingly.
    dconf = lib.mkIf (host.is.linux && host.is.workstation) {
      settings = with lib.hm.gvariant; {
        "com/github/stunkymonkey/nautilus-open-any-terminal" = {
          terminal = "${lib.getExe config.programs.kitty.package}";
        };
      };
    };

    programs = {
      fuzzel = lib.mkIf config.programs.fuzzel.enable {
        settings.main.terminal = "${lib.getExe config.programs.kitty.package}";
      };
    };

    wayland.windowManager = {
      hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
        settings = {
          bind = [
            "$mod, T, exec, ${lib.getExe config.programs.kitty.package}"
          ];
        };
      };
      wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
        settings = {
          command = {
            # Super+T launches a terminal.
            binding_terminal = "<super> KEY_T";
            command_terminal = "${lib.getExe config.programs.kitty.package}";
          };
        };
      };
    };

    xresources.properties = {
      "*background" = getColor "base";
      "*foreground" = getColor "text";
      # Black.
      "*color0" = getColor "surface1";
      "*color8" = getColor "surface2";
      # Red.
      "*color1" = getColor "red";
      "*color9" = getColor "red";
      # Green.
      "*color2" = getColor "green";
      "*color10" = getColor "green";
      # Yellow.
      "*color3" = getColor "yellow";
      "*color11" = getColor "yellow";
      # Blue.
      "*color4" = getColor "blue";
      "*color12" = getColor "blue";
      # Magenta.
      "*color5" = getColor "pink";
      "*color13" = getColor "pink";
      # Cyan.
      "*color6" = getColor "teal";
      "*color14" = getColor "teal";
      # White.
      "*color7" = getColor "subtext1";
      "*color15" = getColor "subtext0";

      # Xterm appearance.
      "XTerm*background" = getColor "base";
      "XTerm*foreground" = getColor "text";
      "XTerm*letterSpace" = 0;
      "XTerm*lineSpace" = 0;
      "XTerm*geometry" = "132x50";
      "XTerm.termName" = "xterm-256color";
      "XTerm*internalBorder" = 2;
      "XTerm*faceName" = "FiraCode Nerd Font Mono:size=14:style=Medium:antialias=true";
      "XTerm*boldFont" = "FiraCode Nerd Font Mono:size=14:style=Bold:antialias=true";
      "XTerm*boldColors" = true;
      "XTerm*cursorBlink" = true;
      "XTerm*cursorUnderline" = false;
      "XTerm*saveline" = 2048;
      "XTerm*scrollBar" = false;
      "XTerm*scrollBar_right" = false;
      "XTerm*urgentOnBell" = true;
      "XTerm*depth" = 24;
      "XTerm*utf8" = true;
      "XTerm*locale" = false;
      "XTerm.vt100.metaSendsEscape" = true;
    };
    xdg = {
      terminal-exec = {
        settings = {
          default = [ "kitty.desktop" ];
        };
      };
    };
  };
}
