{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  terminalEmulators = {
    alacritty = rec {
      launchCommand = lib.getExe config.programs.alacritty.package;
      fuzzelExecute = "${launchCommand} -e";
      nautilusIdentifier = "alacritty";
      desktopFileId = "Alacritty.desktop";
    };
    foot = rec {
      launchCommand = lib.getExe config.programs.foot.package;
      fuzzelExecute = "${launchCommand} -e";
      nautilusIdentifier = "foot";
      desktopFileId = "foot.desktop";
    };
    ghostty = rec {
      launchCommand = lib.getExe config.programs.ghostty.package;
      fuzzelExecute = "${launchCommand} -e";
      nautilusIdentifier = "ghostty";
      desktopFileId = "com.mitchellh.ghostty.desktop";
    };
    kitty = rec {
      launchCommand = lib.getExe config.programs.kitty.package;
      fuzzelExecute = "${launchCommand} --";
      nautilusIdentifier = "kitty";
      desktopFileId = "kitty.desktop";
    };
    wezterm = rec {
      launchCommand = lib.getExe config.programs.wezterm.package;
      fuzzelExecute = "${launchCommand} start --";
      nautilusIdentifier = "wezterm";
      desktopFileId = "org.wezfurlong.wezterm.desktop";
    };
  };
  defaultTerminal = terminalEmulators.kitty;
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
    ./tmux.nix
    ./wezterm.nix
    ./zellij.nix
  ];

  config = lib.mkIf host.is.workstation {

    # User specific dconf terminal-related settings. Nautilus is only installed
    # on workstations, so gate this setting accordingly.
    dconf = lib.mkIf (host.is.linux && host.is.workstation) {
      settings = with lib.hm.gvariant; {
        "com/github/stunkymonkey/nautilus-open-any-terminal" = {
          terminal = defaultTerminal.nautilusIdentifier;
        };
      };
    };

    programs = {
      fuzzel = lib.mkIf config.programs.fuzzel.enable {
        settings.main.terminal = defaultTerminal.fuzzelExecute;
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
