{ desktop, hostname, lib, pkgs, username, ... }:
let
  defaultDns = [ "1.1.1.1" "1.0.0.1" ];
  # https://nixos.wiki/wiki/Steam
  isGamestation = if (hostname == "phasma" || hostname == "vader") && (desktop != null) then true else false;
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  hasRazerPeripherals = if (hostname == "phasma" || hostname == "vader") then true else false;
  needsLowLatencyPipewire = if (hostname == "phasma" || hostname == "vader") then true else false;
  saveBattery = if (hostname != "phasma" && hostname != "vader") then true else false;

  # Define DNS settings for specific users
  # - https://cleanbrowsing.org/filters/
  userDnsSettings = {
    # Security Filter:
    # - Blocks access to phishing, spam, malware and malicious domains.
    martin = [ "185.228.168.9" "185.228.169.9" ];

    # Adult Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It does not block proxy or VPNs, nor mixed-content sites.
    # - Sites like Reddit are allowed.
    # - Google and Bing are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    louise = [ "185.228.168.10" "185.228.169.11" ];

    # Family Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It also blocks proxy and VPN domains that are used to bypass the filters.
    # - Mixed content sites (like Reddit) are also blocked.
    # - Google, Bing and Youtube are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    agatha = [ "185.228.168.168" "185.228.169.168" ];
  };
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop};

  boot = {
    # Enable the threadirqs kernel parameter to reduce audio latency
    # - Inpired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" "threadirqs" ];
    plymouth = {
      enable = true;
    };
  };

  # https://nixos.wiki/wiki/PipeWire
  # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
  # Debugging
  #  - pw-top                                            # see live stats
  #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync in "bad")
  #  - pw-metadata -n settings 0                         # see current quantums
  #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
  #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
  environment.etc = let
    json = pkgs.formats.json {};
  in
  lib.mkIf (needsLowLatencyPipewire) {
    # Change this to use: services.pipewire.extraConfig.pipewire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate          = 48000
        default.clock.allowed-rates = [ 48000 ]
        default.clock.quantum       = 64
        default.clock.min-quantum   = 64
        default.clock.max-quantum   = 64
      }
      context.modules = [
        {
          name = libpipewire-module-rt
          args = {
            nice.level = -11
            rt.prio = 88
          }
        }
      ]
    '';
    # Change this to use: services.pipewire.extraConfig.pipewire-pulse
    "pipewire/pipewire-pulse.d/92-low-latency.conf".source = json.generate "92-low-latency.conf" {
      context.modules = [
        {
          name = "libpipewire-module-protocol-pulse";
          args = {
            pulse.min.req     = "64/48000";
            pulse.default.req = "64/48000";
            pulse.max.req     = "64/48000";
            pulse.min.quantum = "64/48000";
            pulse.max.quantum = "64/48000";
          };
        }
      ];
      stream.properties = {
        node.latency = "64/48000";
        resample.quality = 4;
      };
    };
    # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
    # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3241
    # cat /nix/store/*-wireplumber-*/share/wireplumber/main.lua.d/50-alsa-config.lua
    "wireplumber/main.lua.d/92-low-latency.lua".text = ''
      alsa_monitor.rules = {
        {
          matches = {
            {
              -- Matches all sources.
              { "node.name", "matches", "alsa_input.*" },
            },
            {
              -- Matches all sinks.
              { "node.name", "matches", "alsa_output.*" },
            },
          },
          apply_properties = {
            ["audio.rate"] = "48000",
            ["api.alsa.headroom"] = 128,             -- Default: 0
            ["api.alsa.period-num"] = 2,             -- Default: 2
            ["api.alsa.period-size"] = 512,          -- Default: 1024
            ["api.alsa.disable-batch"] = false,      -- generally, USB soundcards use the batch mode
            ["resample.quality"] = 4,
            ["resample.disable"] = false,
            ["session.suspend-timeout-seconds"] = 0,
          },
        },
      }
    '';
  };

  environment.systemPackages = with pkgs; lib.optionals (isInstall) [
    appimage-run
    pavucontrol
    pulseaudio
    wmctrl
    xdotool
    ydotool
  ] ++ lib.optionals (isGamestation) [
    mangohud
  ] ++ lib.optionals (isInstall && hasRazerPeripherals) [
    polychromatic
  ];

  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
      fira
      liberation_ttf
      noto-fonts-emoji
      source-serif
      twitter-color-emoji
      work-sans
    ] ++ lib.optionals (isInstall) [
      ubuntu_font_family
    ];

    fontconfig = {
      antialias = true;
      cache32Bit = isGamestation;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" ];
        monospace = [ "FiraCode Nerd Font Mono" "Symbols Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" "Twitter Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  networking = {
    networkmanager = {
      enable = true;
      # Conditionally set Public DNS based on username, defaulting if user not matched
      insertNameservers = if builtins.hasAttr username userDnsSettings then
                            userDnsSettings.${username}
                          else
                            defaultDns;
      wifi = {
        backend = "iwd";
        powersave = saveBattery;
      };
    };
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = isGamestation;
    };
    openrazer = lib.mkIf (hasRazerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
    pulseaudio.enable = lib.mkForce false;
    sane = lib.mkIf (isInstall) {
      enable = true;
      #extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };

  programs = {
    chromium = {
      # chromium.enable just enables the Chromium policies.
      enable = isInstall;
      extraOpts = {
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "BuiltInDnsClientEnabled" = false;
        "DeviceMetricsReportingEnabled" = true;
        "ReportDeviceCrashReportInfo" = false;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "en-GB"
          "en-US"
        ];
        "VoiceInteractionHotwordEnabled" = false;
      };
    };
    firefox = {
      enable = true;
      languagePacks = [ "en-GB" ];
      package = pkgs.firefox;
    };
    steam = lib.mkIf (isGamestation) {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
    system-config-printer = lib.mkIf (isInstall) {
      enable = if (desktop == "mate") then true else false;
    };
  };

  services = {
    flatpak = lib.mkIf (isInstall) {
      enable = true;
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = isGamestation;
      jack.enable = false;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    printing = lib.mkIf (isInstall) {
      enable = true;
      drivers = with pkgs; [ gutenprint hplip ];
    };
    system-config-printer.enable = isInstall;

    # Provides users with access to all Elgato StreamDecks.
    # https://github.com/muesli/deckmaster
    # https://gitlab.gnome.org/World/boatswain/-/blob/main/README.md#udev-rules
    udev.extraRules = ''
      # Deckmaster needs write access to uinput to simulate keypresses.
      # Users wanting to use Deckmaster should be added to the input group.
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"

      # Elgato Stream Deck Mini
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Mini (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Original
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck Original (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck MK.2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck XL
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck XL (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="008f", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck Pedal
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", TAG+="uaccess", SYMLINK+="streamdeck-pedal"

      # Expose important timers the members of the audio group
      # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
    '';

    # Disable xterm
    xserver = {
      desktopManager.xterm.enable = false;
      # Disable autoSuspend; my Pantheon session kept auto-suspending
      # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
      displayManager.gdm.autoSuspend = if (desktop == "pantheon") then true else false;
      excludePackages = [ pkgs.xterm ];
    };
  };

  security = {
    # Allow members of the "audio" group to set RT priorities
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L87
    pam.loginLimits = [
      { domain = "@audio"; item = "memlock"; type = "-"   ; value = "unlimited"; }
      { domain = "@audio"; item = "rtprio" ; type = "-"   ; value = "99"       ; }
      { domain = "@audio"; item = "nofile" ; type = "soft"; value = "99999"    ; }
      { domain = "@audio"; item = "nofile" ; type = "hard"; value = "99999"    ; }
    ];
    rtkit.enable = true;
  };

  systemd.services = {
    configure-flathub-repo = lib.mkIf (isInstall) {
      wantedBy = ["multi-user.target"];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
    };
    configure-appcenter-repo = lib.mkIf (isInstall && desktop == "pantheon") {
      wantedBy = ["multi-user.target"];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists appcenter https://flatpak.elementary.io/repo.flatpakrepo
      '';
    };
    disable-wifi-powersave = lib.mkIf (!saveBattery) {
      wantedBy = ["multi-user.target"];
      path = [ pkgs.iw ];
      script = ''
        iw dev wlan0 set power_save off
      '';
    };
  };

  xdg.portal = {
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
    enable = true;
    xdgOpenUsePortal = true;
  };
}
