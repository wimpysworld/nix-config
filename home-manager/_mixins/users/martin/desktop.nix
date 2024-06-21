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
      background-color = "#1E1E2E";
      badge-color-set = false;
      bold-color-set = false;
      cell-height-scale = mkDouble 1.0;
      cell-width-scale = mkDouble 1.0;
      cursor-background-color = "#F5E0DC";
      cursor-blink-mode = "on";
      cursor-colors-set = true;
      cursor-foreground-color = "#1E1E2E";
      default-size-columns = mkInt32 132;
      default-size-rows = mkInt32 50;
      draw-margin = mkInt32 80;
      font = "FiraCode Nerd Font Mono Medium 13";
      foreground-color = "#CDD6F4";
      highlight-background-color = "#F5E0DC";
      highlight-colors-set = true;
      highlight-foreground-color = "#1E1E2E";
      palette = [ "#BAC2DE" "#F38BA8" "#A6E3A1" "#F9E2AF" "#89B4FA" "#F5C2E7" "#94E2D5" "#585B70" "#A6ADC8" "#F38BA8" "#A6E3A1" "#F9E2AF" "#89B4FA" "#F5C2E7" "#94E2D5" "#45475A" ];
      scrollback-unlimited = true;
      terminal-title = "";
      use-system-font = true;
      use-theme-colors = false;
      visible-name = "Default";
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
      theme-dark = "Catppuccin-Mocha";
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
      style-scheme = "catppuccin_mocha";
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
      command = "caja --no-desktop";
    } // lib.optionalAttrs (desktop == "gnome") {
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
    "org/gnome/desktop/default/applications/terminal" = {
      exec = "alacritty";
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
      menu-button-terminal = "alacritty";
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

    "${config.xdg.configHome}/tilix/schemes/Catppuccin-Mocha.json".text = ''
    {
      "name": "Catppuccin Mocha",
      "comment": "Soothing pastel theme for Tilix",
      "background-color": "#1e1e2e",
      "foreground-color": "#cdd6f4",
      "badge-color": "#585b70",
      "bold-color": "#585b70",
      "cursor-background-color": "#f5e0dc",
      "cursor-foreground-color": "#1e1e2e",
      "highlight-background-color": "#f5e0dc",
      "highlight-foreground-color": "#1e1e2e",
      "palette": [
        "#bac2de",
        "#f38ba8",
        "#a6e3a1",
        "#f9e2af",
        "#89b4fa",
        "#f5c2e7",
        "#94e2d5",
        "#585b70",
        "#a6adc8",
        "#f38ba8",
        "#a6e3a1",
        "#f9e2af",
        "#89b4fa",
        "#f5c2e7",
        "#94e2d5",
        "#45475a"
      ],
      "use-badge-color": false,
      "use-bold-color": false,
      "use-cursor-color": true,
      "use-highlight-color": true,
      "use-theme-colors": false
    }
    '';

    ".local/share/blackbox/schemes/Catppuccin-Mocha.json".text = ''
      {
        "name": "Catppuccin-Mocha",
        "comment": "Soothing pastel theme for the high-spirited!",
        "background-color": "#1E1E2E",
        "foreground-color": "#CDD6F4",
        "badge-color": "#585B70",
        "bold-color": "#585B70",
        "cursor-background-color": "#F5E0DC",
        "cursor-foreground-color": "#1E1E2E",
        "highlight-background-color": "#F5E0DC",
        "highlight-foreground-color": "#1E1E2E",
        "palette": [
          "#45475A",
          "#F38BA8",
          "#A6E3A1",
          "#F9E2AF",
          "#89B4FA",
          "#F5C2E7",
          "#94E2D5",
          "#BAC2DE",
          "#585B70",
          "#F38BA8",
          "#A6E3A1",
          "#F9E2AF",
          "#89B4FA",
          "#F5C2E7",
          "#94E2D5",
          "#A6ADC8"
        ],
        "use-badge-color": false,
        "use-bold-color": false,
        "use-cursor-color": true,
        "use-highlight-color": true,
        "use-theme-colors": false
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

  systemd.user.services =  lib.mkIf (isLinux) {
    maestral_qt = {
      Unit = {
        Description = "Maestal Qt";
      };
      Service = {
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

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
