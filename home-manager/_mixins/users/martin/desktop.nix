{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  isWorkstation = if (desktop != null) then true else false;
  isStreamstation = if (hostname == "phasma" || hostname == "vader") && (isWorkstation) then true else false;
  isThinkpad = if (hostname == "tanis" || hostname == "sidious") then true else false;
in
{
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; lib.mkIf (isLinux) {
    ### Various Applications ###
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
      font = "FiraCode Nerd Font Mono Medium 13";
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

    "com/raggesilver/BlackBox" = {
      cursor-blink-mode = lib.hm.gvariant.mkUint32 1;
      cursor-shape = lib.hm.gvariant.mkUint32 0;
      easy-copy-paste = true;
      floating-controls = true;
      floating-controls-hover-area = lib.hm.gvariant.mkUint32 20;
      font = "FiraCode Nerd Font Mono Medium 13";
      pretty = true;
      remember-window-size = true;
      scrollback-lines = lib.hm.gvariant.mkUint32 10240;
      theme-dark = "Adwaita Dark";
      window-height = lib.hm.gvariant.mkUint32 1150;
      window-width = lib.hm.gvariant.mkUint32 1450;
    };

    "io/github/celluloid-player/celluloid" = lib.optionalAttrs (desktop != "gnome") {
      csd-enable = false;
    } // {
      dark-theme-enable = true;
    };

    "org/gnome/meld" = {
      custom-font = "FiraCode Nerd Font Mono Medium 13";
      indent-width = mkInt32 4;
      insert-spaces-instead-of-tabs = true;
      highlight-current-line = true;
      show-line-numbers = true;
      prefer-dark-theme = true;
      highlight-syntax = true;
      style-scheme = "Yaru-dark";
    };

    "org/gnome/rhythmbox/plugins" = {
      active-plugins = [ "rb" "power-manager" "mpris" "iradio" "generic-player" "audiocd" "android" ];
    };

    "org/gnome/rhythmbox/podcast" = {
      download-interval = "manual";
    };

    "org/gnome/rhythmbox/rhythmdb" = {
      locations = [ "file://${config.home.homeDirectory}/Studio/Music" ];
      monitor-library = true;
    };

    "org/gnome/rhythmbox/sources" = {
      browser-views = "genres-artists-albums";
      visible-columns = [ "post-time" "duration" "track-number" "album" "genre" "beats-per-minute" "play-count" "artist" ];
    };

    "org/gnome/SoundRecorder" = {
      audio-channel = "mono";
      audio-profile = "flac";
    };

    "com/github/fabiocolacio/marker/preferences/editor" = {
      auto-indent = true;
      enable-syntax-theme = true;
      replace-tabs = true;
      show-spaces = false;
      spell-check = false;
      syntax-theme = "Yaru-dark";
    };

    "com/github/fabiocolacio/marker/preferences/preview" = {
      css-theme = "GithubDark.css";
      highlight-toggle = true;
    };

    "com/github/fabiocolacio/marker/preferences/window" = {
      enable-dark-mode = true;
      view-mode = "editor-only";
    };

    "com/github/wwmm/easyeffects" = {
      bypass = false;
      process-all-inputs = false;
      process-all-outputs = false;
      show-native-plugin-ui = true;
      use-cubic-volumes = false;
    };

    "com/github/wwmm/easyeffects/spectrum" = {
      height = 240;
      line-width = mkDouble 2.0;
      n-points = 100;
      rounded-corners = true;
      show-bar-border = true;
      type = "Bars";
    };

    "com/github/wwmm/easyeffects/streaminputs" = {
      blocklist = [ "input.Mic-Loopback" ];
      use-default-input-device = true;
    };

    "com/github/wwmm/easyeffects/streamoutputs" = {
      blocklist = [ "output.Mic-Loopback" ];
    };

    ### Common Desktop settings ###
    "net/launchpad/plank/docks/dock1" = lib.optionalAttrs (desktop == "mate" || desktop == "pantheon") {
      dock-items = [ "brave-browser.dockitem" "Wavebox.dockitem" "org.telegram.desktop.dockitem" "discord.dockitem" "org.gnome.Fractal.dockitem" "org.squidowl.halloy.dockitem" "code.dockitem" "GitKraken.dockitem" "com.obsproject.Studio.dockitem" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" =  {
      binding = "<Super>e";
      name = "File Manager";
    } // lib.optionalAttrs (desktop == "pantheon") {
      command = "io.elementary.files -n ~/";
    } // lib.optionalAttrs (desktop == "gnome") {
      command = "nautilus -w ~/";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>t";
      name = "Terminal";
      command = "rio";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Primary><Alt>t";
      name = "Terminal";
      command = "rio";
    };

    "org/gnome/desktop/background" = lib.optionalAttrs (desktop == "gnome" || desktop == "pantheon") {
      picture-options = "zoom";
    } // lib.optionalAttrs (hostname == "phasma") {
      picture-uri = "file:///etc/backgrounds/DeterminateColorway-3440x1440.png";
      picture-uri-dark = "file:///etc/backgrounds/DeterminateColorway-1920x1200.png";
    } // lib.optionalAttrs (hostname == "sidious") {
      picture-uri = "file:///etcbackgrounds/DeterminateColorway-3840x2160.png";
      picture-uri-dark = "file:///etc/backgrounds/DeterminateColorway-1920x1200.png";
    } // lib.optionalAttrs (hostname == "tanis") {
      picture-uri = "file:///etc/backgrounds/DeterminateColorway-1920x1200.png";
      picture-uri-dark = "file:///etc/backgrounds/DeterminateColorway-1920x1200.png";
    } // lib.optionalAttrs (hostname == "vader") {
      picture-uri = "file:///etc/backgrounds/DeterminateColorway-2560x1440.png";
      picture-uri-dark = "file:///etc/backgrounds/DeterminateColorway-2560x1440.png";
    };

    "org/gnome/desktop/screensaver" = lib.optionalAttrs (desktop == "gnome" || desktop == "pantheon") {
      picture-uri = "file://etc/backgrounds/DeterminateColorway-3840x2160.png";
    };

    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "grp:alt_shift_toggle" "caps:none" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = mkInt32 8;
      workspace-names = [ "Web" "Work" "Chat" "Code" "Term" "Cast" "Virt" "Fun" ];
    };

    ### Pantheon ###
    "io/elementary/terminal/settings" = lib.optionalAttrs (desktop == "pantheon") {
      unsafe-paste-alert = false;
    };

    ### GNOME Desktop ###
    "org/gnome/desktop/default/applications/terminal" = lib.optionalAttrs (desktop == "gnome") {
      exec = "rio";
      exec-arg = "--command";
    };

    "org/gnome/mutter" = lib.optionalAttrs (desktop == "gnome") {
      # Disable Mutter edge-tiling because tiling-assistant extension handles it
      edge-tiling = false;
    };

    "org/gnome/mutter/keybindings" = lib.optionalAttrs (desktop == "gnome") {
      # Disable Mutter toggle-tiled because tiling-assistant extension handles it
      toggle-tiled-left = mkEmptyArray type.string;
      toggle-tiled-right = mkEmptyArray type.string;
    };

    "org/gnome/shell" = lib.optionalAttrs (desktop == "gnome") {
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
      ]
      ++ lib.optionals (isThinkpad) [ "thinkpad-battery-threshold@marcosdalvarez.org" ];
      favorite-apps = [ "brave-browser.desktop" "Wavebox.desktop" "org.telegram.desktop.desktop" "discord.desktop" "org.gnome.Fractal.desktop" "org.squidowl.halloy.desktop" "code.desktop" "GitKraken.desktop" "com.obsproject.Studio.desktop" ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = lib.optionalAttrs (desktop == "gnome") {
      application-list = [ "brave-browser.desktop:1" "Wavebox.desktop:2" "discord.desktop:2" "org.telegram.desktop.desktop:3" "org.squidowl.halloy.desktop:3" "org.gnome.Fractal.desktop:3" "code.desktop:4" "GitKraken.desktop:4" "com.obsproject.Studio.desktop:6" ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      background-opacity = mkDouble 0.0;
      transparency-mode = "FIXED";
    };

    "org/gnome/shell/extensions/freon" = lib.optionalAttrs (desktop == "gnome") {
      hot-sensors = [ "__average__" ];
    };

    "org/gnome/shell/extensions/Logo-menu" = lib.optionalAttrs (desktop == "gnome") {
      menu-button-system-monitor = "gnome-usage";
      menu-button-terminal = "rio";
    };

    "org/gnome/shell/extensions/thinkpad-battery-threshold" = lib.optionalAttrs (desktop == "gnome" && isThinkpad) {
      color-mode = false;
    };

    "org/gnome/shell/extensions/tiling-assistant" = lib.optionalAttrs (desktop == "gnome") {
      enable-advanced-experimental-features = true;
      show-layout-panel-indicator = true;
      single-screen-gap = mkInt32 10;
      window-gap = mkInt32 10;
      maximize-with-gap = true;
    };

    "org/gnome/shell/extensions/vitals" = lib.optionalAttrs (desktop == "gnome") {
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

    "org/gnome/desktop/wm/keybindings" = lib.optionalAttrs (desktop == "gnome") {
      # Disable maximise/unmaximise because tiling-assistant extension handles it
      maximize = mkEmptyArray type.string;
      unmaximize = mkEmptyArray type.string;
    };

    ### MATE Desktop ###
    "org/mate/desktop/peripherals/keyboard/kbd" = lib.optionalAttrs (desktop == "mate") {
      options = [ "terminate\tterminate:ctrl_alt_bksp" "caps\tcaps:none" ];
    };

    "org/mate/marco/general" = lib.optionalAttrs (desktop == "mate") {
      num-workspaces = mkInt32 8;
    };

    "org/mate/marco/workspace-names" = lib.optionalAttrs (desktop == "mate") {
      name-1 = " Web ";
      name-2 = " Work ";
      name-3 = " Chat ";
      name-4 = " Code ";
      name-5 = " Term ";
      name-6 = " Cast ";
      name-7 = " Virt ";
      name-8 = " Fun ";
    };
  };

  home.file = {
    # FIXME: Make this a systemd user service
    "${config.xdg.configHome}/autostart/deskmaster-xl.desktop" = lib.mkIf (isStreamstation) {
      text = ''
        [Desktop Entry]
        Name=Deckmaster XL
        Comment=Deckmaster XL
        Type=Application
        Exec=deckmaster -deck ${config.home.homeDirectory}/Studio/StreamDeck/Deckmaster-xl/main.deck
        Categories=
        Terminal=false
        NoDisplay=true
        StartupNotify=false
      '';
    };

    "${config.xdg.configHome}/easyeffects/input/mic-vader-oktava.json" = lib.mkIf (isStreamstation) {
      text = ''
        {
            "input": {
                "blocklist": [
                    "input.Mic-Loopback"
                ],
                "compressor#0": {
                    "attack": 10.0,
                    "boost-amount": 6.0,
                    "boost-threshold": -72.0,
                    "bypass": false,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "input-gain": 0.0,
                    "knee": -20.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 6.0,
                    "mode": "Downward",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "release": 60.0,
                    "release-threshold": -100.0,
                    "sidechain": {
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right",
                        "type": "Feed-forward"
                    },
                    "stereo-split": false,
                    "threshold": -18.0,
                    "wet": 0.0
                },
                "deepfilternet#0": {
                    "attenuation-limit": 100.0,
                    "max-df-processing-threshold": 20.0,
                    "max-erb-processing-threshold": 30.0,
                    "min-processing-buffer": 0,
                    "min-processing-threshold": -10.0,
                    "post-filter-beta": 0.02
                },
                "deesser#0": {
                    "bypass": false,
                    "detection": "RMS",
                    "f1-freq": 6000.0,
                    "f1-level": 0.0,
                    "f2-freq": 4500.0,
                    "f2-level": 12.0,
                    "f2-q": 1.0,
                    "input-gain": 0.0,
                    "laxity": 15,
                    "makeup": 0.0,
                    "mode": "Wide",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "sc-listen": false,
                    "threshold": -30.0
                },
                "filter#0": {
                    "balance": 0.0,
                    "bypass": false,
                    "equal-mode": "IIR",
                    "frequency": 75.0,
                    "gain": 0.0,
                    "input-gain": 0.0,
                    "mode": "RLC (BT)",
                    "output-gain": 0.0,
                    "quality": 1.0,
                    "slope": "x2",
                    "type": "High-pass",
                    "width": 4.0
                },
                "gate#0": {
                    "attack": 5.0,
                    "bypass": false,
                    "curve-threshold": -50.00000000000007,
                    "curve-zone": -6.0,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "hysteresis": false,
                    "hysteresis-threshold": -12.0,
                    "hysteresis-zone": -6.0,
                    "input-gain": 0.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 0.0,
                    "output-gain": 0.0,
                    "reduction": -24.0,
                    "release": 50.0,
                    "sidechain": {
                        "input": "Internal",
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right"
                    },
                    "stereo-split": false,
                    "wet": 0.0
                },
                "limiter#0": {
                    "alr": false,
                    "alr-attack": 5.0,
                    "alr-knee": 0.0,
                    "alr-release": 50.0,
                    "attack": 5.0,
                    "bypass": false,
                    "dithering": "None",
                    "external-sidechain": false,
                    "gain-boost": false,
                    "input-gain": 0.0,
                    "lookahead": 5.0,
                    "mode": "Herm Thin",
                    "output-gain": 0.0,
                    "oversampling": "None",
                    "release": 5.0,
                    "sidechain-preamp": 0.0,
                    "stereo-link": 100.0,
                    "threshold": -1.5
                },
                "plugins_order": [
                    "stereo_tools#0",
                    "deepfilternet#0",
                    "gate#0",
                    "speex#0",
                    "compressor#0",
                    "filter#0",
                    "deesser#0",
                    "limiter#0"
                ],
                "speex#0": {
                    "bypass": false,
                    "enable-agc": false,
                    "enable-denoise": false,
                    "enable-dereverb": true,
                    "input-gain": 0.0,
                    "noise-suppression": -70,
                    "output-gain": 0.0,
                    "vad": {
                        "enable": false,
                        "probability-continue": 90,
                        "probability-start": 95
                    }
                },
                "stereo_tools#0": {
                    "balance-in": 0.0,
                    "balance-out": 0.0,
                    "bypass": false,
                    "delay": 0.0,
                    "input-gain": 0.0,
                    "middle-level": 0.0,
                    "middle-panorama": 0.0,
                    "mode": "LR > LL (Mono Left Channel)",
                    "mutel": false,
                    "muter": false,
                    "output-gain": 0.0,
                    "phasel": false,
                    "phaser": false,
                    "sc-level": 1.0,
                    "side-balance": 0.0,
                    "side-level": 0.0,
                    "softclip": false,
                    "stereo-base": 0.0,
                    "stereo-phase": 0.0
                }
            }
        }
      '';
    };

    "${config.xdg.configHome}/easyeffects/input/mic-phasma-oktava.json" = lib.mkIf (isStreamstation) {
      text = ''
        {
            "input": {
                "blocklist": [
                    "input.Mic-Loopback"
                ],
                "compressor#0": {
                    "attack": 10.0,
                    "boost-amount": 6.0,
                    "boost-threshold": -72.0,
                    "bypass": false,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "input-gain": 0.0,
                    "knee": -20.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 6.0,
                    "mode": "Downward",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "release": 60.0,
                    "release-threshold": -100.0,
                    "sidechain": {
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right",
                        "type": "Feed-forward"
                    },
                    "stereo-split": false,
                    "threshold": -18.0,
                    "wet": 0.0
                },
                "deepfilternet#0": {
                    "attenuation-limit": 100.0,
                    "max-df-processing-threshold": 20.0,
                    "max-erb-processing-threshold": 30.0,
                    "min-processing-buffer": 0,
                    "min-processing-threshold": -10.0,
                    "post-filter-beta": 0.02
                },
                "deesser#0": {
                    "bypass": false,
                    "detection": "RMS",
                    "f1-freq": 6000.0,
                    "f1-level": 0.0,
                    "f2-freq": 4500.0,
                    "f2-level": 12.0,
                    "f2-q": 1.0,
                    "input-gain": 0.0,
                    "laxity": 15,
                    "makeup": 0.0,
                    "mode": "Wide",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "sc-listen": false,
                    "threshold": -30.0
                },
                "filter#0": {
                    "balance": 0.0,
                    "bypass": false,
                    "equal-mode": "IIR",
                    "frequency": 75.0,
                    "gain": 0.0,
                    "input-gain": 0.0,
                    "mode": "RLC (BT)",
                    "output-gain": 0.0,
                    "quality": 1.0,
                    "slope": "x2",
                    "type": "High-pass",
                    "width": 4.0
                },
                "gate#0": {
                    "attack": 5.0,
                    "bypass": false,
                    "curve-threshold": -40.0,
                    "curve-zone": -6.0,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "hysteresis": false,
                    "hysteresis-threshold": -12.0,
                    "hysteresis-zone": -6.0,
                    "input-gain": 0.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 0.0,
                    "output-gain": 0.0,
                    "reduction": -36.0,
                    "release": 50.0,
                    "sidechain": {
                        "input": "Internal",
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right"
                    },
                    "stereo-split": false,
                    "wet": 0.0
                },
                "limiter#0": {
                    "alr": false,
                    "alr-attack": 5.0,
                    "alr-knee": 0.0,
                    "alr-release": 50.0,
                    "attack": 5.0,
                    "bypass": false,
                    "dithering": "None",
                    "external-sidechain": false,
                    "gain-boost": false,
                    "input-gain": 0.0,
                    "lookahead": 5.0,
                    "mode": "Herm Thin",
                    "output-gain": 0.0,
                    "oversampling": "None",
                    "release": 5.0,
                    "sidechain-preamp": 0.0,
                    "stereo-link": 100.0,
                    "threshold": -1.5
                },
                "plugins_order": [
                    "stereo_tools#0",
                    "deepfilternet#0",
                    "gate#0",
                    "speex#0",
                    "compressor#0",
                    "filter#0",
                    "deesser#0",
                    "limiter#0"
                ],
                "speex#0": {
                    "bypass": false,
                    "enable-agc": false,
                    "enable-denoise": false,
                    "enable-dereverb": true,
                    "input-gain": 0.0,
                    "noise-suppression": -70,
                    "output-gain": 0.0,
                    "vad": {
                        "enable": false,
                        "probability-continue": 90,
                        "probability-start": 95
                    }
                },
                "stereo_tools#0": {
                    "balance-in": 0.0,
                    "balance-out": 0.0,
                    "bypass": false,
                    "delay": 0.0,
                    "input-gain": 0.0,
                    "middle-level": 0.0,
                    "middle-panorama": 0.0,
                    "mode": "LR > LL (Mono Left Channel)",
                    "mutel": false,
                    "muter": false,
                    "output-gain": 0.0,
                    "phasel": false,
                    "phaser": false,
                    "sc-level": 1.0,
                    "side-balance": 0.0,
                    "side-level": 0.0,
                    "softclip": false,
                    "stereo-base": 0.0,
                    "stereo-phase": 0.0
                }
            }
        }
      '';
    };

    ".local/share/blackbox/schemes/Bearded-Dark-Vivid.json".text = ''
      {
          "background-color": "#121214",
          "badge-color": "#E66DFF",
          "bold-color": "#C8C8C8",
          "cursor-background-color": "#FFB638",
          "cursor-foreground-color": "#FFB638",
          "foreground-color": "#C8C8C8",
          "highlight-background-color": "#1E1E20",
          "highlight-foreground-color": "#C8C8C8",
          "name": "Bearded Dark Vivid",
          "comment": "Bearded Dark Vivid",
          "palette": [
              "#121214",
              "#d62b2b",
              "#41dd75",
              "#ffb638",
              "#28a9ff",
              "#e66dff",
              "#14e5d3",
              "#c8c8c8",
              "#434345",
              "#de5656",
              "#a1eebb",
              "#ffc560",
              "#94d4ff",
              "#f2b6ff",
              "#a0f5ed",
              "#e9e9e9"
          ],
          "use-badge-color": true,
          "use-bold-color": true,
          "use-cursor-color": true,
          "use-highlight-color": false,
          "use-theme-colors": false
      }
    '';

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

  services.easyeffects = lib.mkIf (isLinux) {
    enable = true;
    preset = lib.mkIf (isStreamstation) "mic-${hostname}-oktava";
  };

  systemd.user.tmpfiles.rules = lib.mkIf (isLinux) [
    "d ${config.home.homeDirectory}/Audio 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.local/share/org.gnome.SoundRecorder/ - - - - ${config.home.homeDirectory}/Audio/"
  ];

  xdg = {
    desktopEntries = lib.mkIf (isLinux) {
      # Create a desktop entry for the Cider AppImage.
      cider = {
        name = "Cider";
        exec = "${pkgs.appimage-run}/bin/appimage-run -- ${config.home.homeDirectory}/Apps/Cider-linux-appimage-x64.AppImage";
        terminal = false;
        icon = "${config.home.homeDirectory}/Apps/cider.png";
        type = "Application";
        categories = [ "GNOME" "GTK" "AudioVideo" ];
      };
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
