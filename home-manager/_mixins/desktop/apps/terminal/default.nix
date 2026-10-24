{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  terminalEmulators = {
    alacritty = {
      launchCommand = lib.getExe config.programs.alacritty.package;
      desktopFileId = "Alacritty.desktop";
    };
    foot = {
      launchCommand = lib.getExe config.programs.foot.package;
      desktopFileId = "foot.desktop";
    };
    ghostty = {
      launchCommand = lib.getExe config.programs.ghostty.package;
      desktopFileId = "com.mitchellh.ghostty.desktop";
    };
    kitty = {
      launchCommand = lib.getExe config.programs.kitty.package;
      desktopFileId = "kitty.desktop";
    };
    wezterm = {
      launchCommand = lib.getExe config.programs.wezterm.package;
      desktopFileId = "org.wezfurlong.wezterm.desktop";
    };
  };
  defaultTerminal = terminalEmulators.ghostty;
  # Get a colour as a hexadecimal string.
  getColor = colorName: catppuccinPalette.getColor colorName;
in
{
  imports = [
    ./alacritty.nix
    ./blackbox.nix
    ./contour.nix
    ./foot.nix
    ./ghostty.nix
    ./kitty.nix
    ./konsole.nix
    ./mlterm.nix
    ./rio.nix
    ./tmux.nix
    ./wezterm.nix
    ./zellij.nix
  ];

  config = lib.mkIf host.is.workstation {

    # Point tools that read TERMINAL at the default terminal, in login shells
    # and in systemd user services such as the compositor session.
    home.sessionVariables = lib.mkIf host.is.linux {
      TERMINAL = lib.mkDefault "xdg-terminal-exec";
    };
    systemd.user.sessionVariables = lib.mkIf host.is.linux {
      TERMINAL = lib.mkDefault "xdg-terminal-exec";
    };

    programs = {
      fuzzel = lib.mkIf config.programs.fuzzel.enable {
        # Open Terminal=true entries in the default terminal, as Rofi and
        # TERMINAL do. xdg-terminal-exec takes the command without -e.
        settings.main.terminal = lib.getExe pkgs.xdg-terminal-exec;
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
        enable = true;
        settings = {
          default = [ defaultTerminal.desktopFileId ];
        };
      };
    };
  };
}
