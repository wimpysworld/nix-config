{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  getRgb =
    colorName:
    let
      inherit (catppuccinPalette.colors.${colorName}) rgb;
    in
    lib.concatMapStringsSep "," toString [
      rgb.r
      rgb.g
      rgb.b
    ];
  colours = {
    Background = "base";
    Foreground = "text";
    Color0 = "surface1";
    Color1 = "red";
    Color2 = "green";
    Color3 = "yellow";
    Color4 = "blue";
    Color5 = "pink";
    Color6 = "teal";
    Color7 = "subtext1";
  };
  colourScheme = lib.mapAttrs (_: colorName: { Color = getRgb colorName; }) colours;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [ host.desktop ] null (import ../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  hideWindowDecorations = compositor != null && !compositor.capabilities.clientSideDecorations;
in
lib.mkIf
  (
    host.is.linux
    && host.is.workstation
    && noughtyLib.isHost [
      "skrye"
      "zannah"
    ]
  )
  {
    home.packages = [ pkgs.kdePackages.konsole ];

    xdg.configFile."konsolerc".text = lib.generators.toINI { } {
      "Desktop Entry".DefaultProfile = "Catppuccin Mocha.profile";
      "MainWindow".MenuBar = "Disabled";
      KonsoleWindow.RemoveWindowTitleBarAndFrame = hideWindowDecorations;
    };

    xdg.dataFile = {
      "konsole/Catppuccin Mocha.profile".text = lib.generators.toINI { } {
        General = {
          Name = "Catppuccin Mocha";
          Parent = "FALLBACK/";
          TerminalMargin = 2;
        };
        Appearance = {
          ColorScheme = "Catppuccin Mocha";
          Font = "FiraCode Nerd Font Mono,16,-1,5,50,0,0,0,0,0";
        };
        "Cursor Options" = {
          CursorShape = 0;
          UseCustomCursorColor = true;
          CustomCursorColor = getRgb "rosewater";
          CustomCursorTextColor = getRgb "base";
        };
        Scrolling = {
          HistoryMode = 1;
          HistorySize = 65536;
          ScrollBarPosition = 2;
        };
        "Terminal Features".BlinkingCursorEnabled = true;
      };
      "konsole/Catppuccin Mocha.colorscheme".text = lib.generators.toINI { } (
        colourScheme
        // lib.mapAttrs' (name: value: lib.nameValuePair "${name}Faint" value) colourScheme
        // lib.mapAttrs' (name: value: lib.nameValuePair "${name}Intense" value) colourScheme
        // {
          Color0Intense.Color = getRgb "surface2";
          Color7Intense.Color = getRgb "subtext0";
          General = {
            Description = "Catppuccin Mocha";
            Opacity = 1;
            Blur = false;
            ColorRandomization = false;
          };
        }
      );
    };
  }
