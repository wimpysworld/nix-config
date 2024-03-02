{ config, desktop, lib, pkgs, username, ... }:
{
  imports = [
    ../../desktop/chatterino2.nix
    ../../desktop/discord.nix
    ../../desktop/gitkraken.nix
    #../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/vscode.nix
  ];

  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; {
    "ca/desrt/dconf-editor" = {
      show-warning = false;
    };
    "com/gexperts/Tilix" = {
      app-title = "\${appName}: \${directory}";
      paste-strip-trailing-whitespace = true;
      prompt-on-close = true;
      quake-hide-lose-focus = true;
      quake-specific-monitor = mkInt32 0;
      session-name = "\${id}";
      terminal-title-show-when-single = true;
      terminal-title-style = "none";
      use-tabs = true;
      window-style = "normal";
    };

    "com/gexperts/Tilix/keybindings" = {
      win-view-sidebar = "<Primary>F12";
    };

    "com/gexperts/Tilix/profiles" = {
      default = "d1def387-a465-4497-81bc-b8b2de782b2d";
      list = [ "d1def387-a465-4497-81bc-b8b2de782b2d" ];
    };

    "com/gexperts/Tilix/profiles/d1def387-a465-4497-81bc-b8b2de782b2d" = {
      background-color = "#121212121414";
      badge-color = "#E6E66D6DFFFF";
      badge-color-set = true;
      badge-font = "FiraCode Nerd Font Mono 12";
      #badge-text = "\${columns}x\${rows}";
      badge-text = "";
      badge-use-system-font = false;
      bold-color = "#C8C8C8C8C8C8";
      bold-color-set = true;
      bold-is-bright = false;
      cell-height-scale = mkDouble 1.0;
      cell-width-scale = mkDouble 1.0;
      cursor-background-color = "#FFFFB6B63838";
      cursor-blink-mode = "on";
      cursor-colors-set = true;
      cursor-foreground-color = "#FFFFB6B63838";
      default-size-columns = mkInt32 132;
      default-size-rows = mkInt32 50;
      draw-margin = mkInt32 80;
      font = "FiraCode Nerd Font Medium 12";
      foreground-color = "#C8C8C8C8C8C8";
      highlight-background-color = "#1E1E1E1E2020";
      highlight-colors-set = false;
      highlight-foreground-color = "#C8C8C8C8C8C8";
      palette = [ "#121212121414" "#D6D62B2B2B2B" "#4141DDDD7575" "#FFFFB6B63838" "#2828A9A9FFFF" "#E6E66D6DFFFF" "#1414E5E5D3D3" "#C8C8C8C8C8C8" "#434343434545" "#DEDE56565656" "#A1A1EEEEBBBB" "#FFFFC5C56060" "#9494D4D4FFFF" "#F2F2B6B6FFFF" "#A0A0F5F5EDED" "#E9E9E9E9E9E9" ];
      scrollback-unlimited = true;
      terminal-title = "";
      use-system-font = true;
      use-theme-colors = false;
      visible-name = "Bearded Dark Vivid";
    };

    "io/github/celluloid-player/celluloid" = lib.optionalAttrs (desktop != "gnome") {
      csd-enable = false;
    } // {
      dark-theme-enable = true;
    };
    "org/gnome/SoundRecorder" = {
      audio-channel = "mono";
      audio-profile = "flac";
    };
    "org/gnome/TextEditor" = {
      custom-font = "FiraCode Nerd Font Mono Medium 14";
      highlight-current-line = true;
      indent-style = "space";
      show-line-numbers = true;
      show-map = true;
      show-right-margin = true;
      style-scheme = "builder-dark";
      tab-width = mkInt32 4;
      use-system-font = false;
    };
  };

  home.file = {
    ".gitkraken/themes/bearded-vivid-black.jsonc".text = ''
      {
        "meta": {
          "name": "Bearded Vivid Black",
          "scheme": "dark" // must be "light" or "dark"
        },
        "themeValues": {
          // values applied to the entire app
          "root": {
            "red": "#d62c2c",
            "orange": "#ff7135",
            "yellow": "#ffb638",
            "green": "#42dd76",
            "teal": "#14e5d4",
            "blue": "#28a9ff",
            "ltblue": "#94D4FF",
            "purple": "#e66dff",
            "app__bg0": "#141417",
            "toolbar__bg0": "lighten(saturate(@app__bg0, 3%), 1%)",
            "toolbar__bg1": "lighten(@toolbar__bg0, 4%)", //4%
            "toolbar__bg2": "lighten(@toolbar__bg1, 6%)", //6%
            "panel__bg0": "lighten(@app__bg0, 5%)", //5%
            "panel__bg1": "lighten(@panel__bg0, 4%)", //4%
            "panel__bg2": "lighten(@panel__bg1, 4%)", //4%
            "input__bg": "#141417",
            "input-bg-warn-color": "fade(@orange, 60%)",
            "panel-border": "fade(#FFFFFF, 8%)",
            "section-border": "fade(#FFFFFF, 8%)",
            "subtle-border": "fade(#FFFFFF, 4%)",
            "modal-overlay-color": "rgba(0,0,0,.5)",
            // graph colors
            "graph-color-0": "#14E5D4", //cyan
            "graph-color-1": "#28A9FF", //blue
            "graph-color-2": "#8e00c2", //purle
            "graph-color-3": "#E66DFF", //magenta
            "graph-color-4": "#F3B6FF", //lt. magenta
            "graph-color-5": "#D62C2C", //red
            "graph-color-6": "#ff7135", //orange
            "graph-color-7": "#FFB638", //yellow
            "graph-color-8": "#42DD76", //green
            "graph-color-9": "#2ece9d", //teal
            // text colors
            // values starting with . aren't added to the CSS, they're just variables
            ".text-color": "#c8c8c8",
            "text-selected": "@.text-color",
            "text-normal": "fade(@.text-color, 78%)",
            "text-secondary": "fade(@.text-color, 65%)",
            "text-disabled": "fade(@.text-color, 45%)",
            "text-accent": "#28a9ff", //blue
            "text-inverse": "#373737",
            "text-bright": "@.text-color",
            "text-dimmed": "fade(@text-normal, 20%)",
            "text-dimmed-selected": "fade(@text-dimmed, 50%)",
            "text-selected-row": "@text-selected",
            // buttons
            "btn-text": "@text-normal",
            "btn-text-hover": "@text-selected",
            "default-border": "@text-normal",
            "default-bg": "transparent",
            "default-hover": "transparent",
            "default-border-hover": "@text-selected",
            "primary-border": "@blue",
            "primary-bg": "fade(@blue, 10%)", //10%
            "primary-hover": "fade(@blue, 40%)", //40%
            "success-border": "@green",
            "success-bg": "fade(@green, 10%)",
            "success-hover": "fade(@green, 40%)",
            "warning-border": "@orange",
            "warning-bg": "fade(@orange, 10%)",
            "warning-hover": "fade(@orange, 35%)",
            "danger-border": "@red",
            "danger-bg": "fade(@red, 10%)",
            "danger-hover": "fade(@red, 40%)",
            // states
            "hover-row": "fade(@blue, 50%)", //15%
            "danger-row": "fade(@red, 40%)",
            "selected-row": "fade(@blue, 75%)", //20%
            "selected-row-border": "none",
            "warning-row": "fade(@orange, 40%)",
            "droppable": "fade(@yellow, 30%)",
            "drop-target": "fade(@green, 50%)",
            "input--disabled": "fade(#000000, 10%)",
            "link-color": "#14e5d4", //cyan
            "link-color-bright": "#14e5d4", //cyan
            "form-control-focus": "@blue",
            // various app elements
            "scroll-thumb-border": "rgba(0,0,0,0)",
            "scroll-thumb-bg": "rgba(255,255,255,0.15)",
            "scroll-thumb-bg-light": "rgba(0,0,0,0.15)",
            "wip-status": "fade(@blue, 40%)",
            "card__bg": "@panel__bg2",
            "card-shadow": "@rgba(0,0,0,.2)",
            "statusbar__warning-bg": "mixLess(@graph-color-7, @app__bg0, 50%)",
            "label__yellow-color": "#ffb638", //yellow
            "label__light-blue-color": "#28a9ff", //blue
            "label__purple-color": "#e66dff", //magenta
            // component states
            "filtering": "fade(@blue, 50%)",
            "soloing": "fade(@orange, 50%)",
            "checked-out": "fade(@green, 30%)",
            "soloed": "fade(@orange, 30%)",
            "filter-match": "fade(@blue, 50%)",
            "clone__progress": "fade(@blue, 70%)",
            "toolbar__prompt": "fade(@blue, 20%)",
            "verified": "fade(@green, 30%)",
            "unverified": "fade(#ffffff, 10%)",
            "drop-sort-border": "@green",
            // terminal
            "terminal__repo-name-color": "turquoise",
            "terminal__repo-branch-color": "violet",
            "terminal__repo-tag-color": "coral",
            "terminal__repo-upstream-color": "lime",
            "terminal__background": "#121214",
            "terminal__cursor": "#ffb638",
            "terminal__cursorAccent": "#ffb638",
            "terminal__foreground": "#c8c8c8",
            "terminal__selection": "#37373a", //grey-dark
            "terminal__black": "#141417",
            "terminal__red": "#d62c2c",
            "terminal__green": "#42dd76",
            "terminal__yellow": "#ffb638",
            "terminal__blue": "#28a9ff",
            "terminal__magenta": "#e66dff",
            "terminal__cyan": "#14e5d4",
            "terminal__white": "#c8c8c8",
            "terminal__brightBlack": "#434345",
            "terminal__brightRed": "#DE5656",
            "terminal__brightGreen": "#A1EEBB",
            "terminal__brightYellow": "#FFC560",
            "terminal__brightBlue": "#94D4FF",
            "terminal__brightMagenta": "#F3B6FF",
            "terminal__brightCyan": "#A1F5EE,
            "terminal__brightWhite": "#E9E9E9,
            // code editor
            "code-bg": "@app__bg0",
            "code-foreground": "@text-normal",
            "code-blame-color-0": "@graph-color-0",
            "code-blame-color-1": "@graph-color-1",
            "code-blame-color-2": "@graph-color-2",
            "code-blame-color-3": "@graph-color-3",
            "code-blame-color-4": "@graph-color-4",
            "code-blame-color-5": "@graph-color-5",
            "code-blame-color-6": "@graph-color-6",
            "code-blame-color-7": "@graph-color-7",
            "code-blame-color-8": "@graph-color-8",
            "code-blame-color-9": "@graph-color-9",
            "added-line": "fade(@green, 30%)",
            "deleted-line": "fade(@red, 30%)",
            "modified-line": "fade(#000000, 25%)",
            "conflict-info-color": "#14e5d4", //cyan
            "conflict-left-border-color": "#14e5d4", //cyan
            "conflict-left-color": "fade(@conflict-left-border-color, 25%)",
            "conflict-right-border-color": "#ffb638", //yellow
            "conflict-right-color": "fade(@conflict-right-border-color, 25%)",
            "conflict-output-border-color": "#e66dff", //magenta
            "conflict-output-color": "fade(@conflict-output-border-color, 25%)"
          },
          // override specific values just for the toolbar
          "toolbar": {
            "text-selected": "rgba(255,255,255,1)",
            "text-normal": "rgba(255,255,255,.9)",
            "text-secondary": "rgba(255,255,255,.6)",
            "text-disabled": "rgba(255,255,255,.4)",
            "section-border": "rgba(255,255,255,.2)",
            "input__bg": "rgba(0,0,0,.20)",
            "link-color": "#14e5d4", //cyan
            "btn-text": "var(--text-normal)"
          },
          // override specific values just for the tabs bar
          "tabsbar": {
            "text-selected": "rgba(255,255,255,1)",
            "text-normal": "rgba(255,255,255,.9)",
            "text-secondary": "rgba(255,255,255,.6)",
            "text-disabled": "rgba(255,255,255,.4)",
            "section-border": "rgba(255,255,255,.2)",
            "input__bg": "rgba(0,0,0,.20)",
            "link-color": "#14e5d4", //cyan
            "btn-text": "var(--text-normal)"
          }
        }
      }
    '';
  };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/Audio 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.local/share/org.gnome.SoundRecorder/ - - - - ${config.home.homeDirectory}/Audio/"
  ];

  xdg = {
    desktopEntries = {
      # The usbimager icon path is hardcoded, so override the desktop file
      usbimager = {
        name = "USBImager";
        exec = "${pkgs.usbimager}/bin/usbimager";
        terminal = false;
        icon = "usbimager";
        type = "Application";
        categories = [ "System" "Application" ];
      };
    };
  };
}
