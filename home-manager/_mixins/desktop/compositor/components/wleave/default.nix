{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  palette = catppuccinPalette;
  icons = "${pkgs.wleave}/share/wleave/icons";
  # Centre the menu on the primary output: a vertical band on portrait
  # displays, a horizontal band on ultrawide.
  wleaveMargins =
    if display.primaryIsPortrait then
      "--margin-top 960 --margin-bottom 960"
    else if display.primaryIsUltrawide then
      "--margin-left 540 --margin-right 540"
    else
      "";
  # One wrapper so the waybar button and the fuzzel session menu share a single
  # invocation. Redirecting XDG_CONFIG_HOME to an empty directory drops the
  # catppuccin gtk.css `@import` (loaded at PRIORITY_USER, which would otherwise
  # force an opaque window) out of wleave's cascade, so its own
  # Catppuccin-coloured CSS wins and the background stays transparent. wleave
  # also discovers its config via XDG_CONFIG_HOME, so the layout and CSS are
  # passed explicitly.
  sessionMenu = pkgs.writeShellApplication {
    name = "wleave-session";
    runtimeInputs = [ pkgs.wleave ];
    text = ''
      exec env XDG_CONFIG_HOME=${pkgs.emptyDirectory} wleave \
        --no-version-info \
        --buttons-per-row 5 \
        ${wleaveMargins} \
        --layout ${config.xdg.configHome}/wleave/layout.json \
        --css ${config.xdg.configHome}/wleave/style.css "$@"
    '';
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ sessionMenu ];

  programs = {
    wleave = {
      enable = true;
      # wleave's bundled SVG icons, tinted to Catppuccin through the `color`
      # property (the icons use `currentColor`), with the original wlogout labels.
      settings.buttons = [
        {
          label = "lock";
          action = "hypr-session lock";
          text = "  Lock  ";
          keybind = "l";
          icon = "${icons}/lock.svg";
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
          icon = "${icons}/suspend.svg";
        }
        {
          label = "logout";
          action = "hypr-session logout";
          text = " Logout ";
          keybind = "e";
          icon = "${icons}/logout.svg";
        }
        {
          label = "reboot";
          action = "hypr-session reboot";
          text = " Reboot ";
          keybind = "r";
          icon = "${icons}/reboot.svg";
        }
        {
          label = "shutdown";
          action = "hypr-session shutdown";
          text = "Shutdown";
          keybind = "s";
          icon = "${icons}/shutdown.svg";
        }
      ];
      # Match the original wlogout geometry. The launcher passes the same
      # `--buttons-per-row 5` and per-edge margins, and the button margin below
      # is unchanged from wlogout. GTK4 and Libadwaita add button padding, a
      # minimum size and chrome that GTK3 wlogout never imposed, so reset those
      # and let the grid plus margins size the buttons exactly as before.
      style = ''
        window {
            font-family: FiraCode Nerd Font Mono, monospace;
            font-size: 18pt;
            color: ${palette.getColor "text"};
        }

        /* The catppuccin-gtk theme paints the window opaque through its
           `.background { background-color: @window_bg_color }` rule. Override
           that exact selector with higher specificity to clear the fill so the
           compositor blur shows through, and carry the translucent Catppuccin
           tint on the background-image layer above the blur. */
        window.background {
            background-color: transparent;
            background-image: linear-gradient(${palette.mkRgba "base" "0.5"}, ${palette.mkRgba "base" "0.5"});
        }

        button {
            padding: 0;
            min-width: 0;
            min-height: 0;
            border: none;
            box-shadow: none;
            outline: none;
            color: ${palette.getColor "text"};
            background-color: ${palette.mkRgba "base" "0"};
            margin: 100px 5px 100px 5px;
            transition: box-shadow 0.2s ease-in-out, background-color 0.2s ease-in-out;
        }

        button:hover {
            background-color: ${palette.mkRgba "surface0" "0.1"};
        }

        button:focus {
            color: ${palette.getColor "crust"};
            background-color: ${palette.getColor "blue"};
        }

        /* Per-button Catppuccin accent on the icon and label for a bit of
           flair. Icons inherit `color` via `currentColor`. `:not(:focus)` keeps
           the focused button flipping to crust-on-blue for contrast. */
        button#lock:not(:focus) {
            color: ${palette.getColor "blue"};
        }

        button#logout:not(:focus) {
            color: ${palette.getColor "yellow"};
        }

        button#suspend:not(:focus) {
            color: ${palette.getColor "sky"};
        }

        button#reboot:not(:focus) {
            color: ${palette.getColor "peach"};
        }

        button#shutdown:not(:focus) {
            color: ${palette.getColor "red"};
        }
      '';
    };
  };
}
