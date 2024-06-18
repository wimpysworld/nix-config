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

  environment.etc = {
    "backgrounds/DeterminateColorway-1920x1080.png".source = ../configs/backgrounds/DeterminateColorway-1920x1080.png;
    "backgrounds/DeterminateColorway-1920x1200.png".source = ../configs/backgrounds/DeterminateColorway-1920x1200.png;
    "backgrounds/DeterminateColorway-2560x1440.png".source = ../configs/backgrounds/DeterminateColorway-2560x1440.png;
    "backgrounds/DeterminateColorway-3440x1440.png".source = ../configs/backgrounds/DeterminateColorway-3440x1440.png;
    "backgrounds/DeterminateColorway-3840x2160.png".source = ../configs/backgrounds/DeterminateColorway-3840x2160.png;
  };

  environment.systemPackages = with pkgs; lib.optionals (isInstall) [
    appimage-run
    (chromium.override { enableWideVine = true; })
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
       dns = "systemd-resolved";
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
    appimage.binfmt = true;
    chromium = {
      # Configures policies for Chromium, Chrome and Brave
      # - https://help.kagi.com/kagi/getting-started/setting-default.html
      # - https://chromeenterprise.google/policies/
      # - chromium.enable just enables the Chromium policies.
      enable = isInstall;
      extraOpts = {
        # Misc; privacy and data collection prevention
        "BrowserNetworkTimeQueriesEnabled" = false;
        "DeviceMetricsReportingEnabled" = false;
        "DomainReliabilityAllowed" = false;
        "FeedbackSurveysEnabled" = false;
        "MetricsReportingEnabled" = false;
        "SpellCheckServiceEnabled" = false;
        # Misc; DNS
        "BuiltInDnsClientEnabled" = false;
        # Misc; Tabs
        "NTPCardsVisible" = false;
        "NTPCustomBackgroundEnabled" = false;
        "NTPMiddleSlotAnnouncementVisible" = false;
        # Misc; Downloads
        "DefaultDownloadDirectory" = "/home/${username}/Downloads";
        "DownloadDirectory" = "/home/${username}/Downloads";
        "PromptForDownloadLocation" = true;
        # Misc
        "AllowSystemNotifications" = true;
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "BackgroundModeEnabled" = false;
        "BookmarkBarEnabled" = false;
        "BrowserAddPersonEnabled" = true;
        "BrowserLabsEnabled" = false;
        "PromotionalTabsEnabled" = false;
        "ShoppingListEnabled" = false;
        "ShowFullUrlsInAddressBar" = true;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "en-GB"
          "en-US"
        ];
        # Cloud Reporting
        "CloudReportingEnabled" = false;
        "CloudProfileReportingEnabled" = false;
        # Content settings
        "DefaultGeolocationSetting" = 3;
        "DefaultImagesSetting" = 1;
        "DefaultPopupsSetting" = 1;
        # Default search provider; Kagi
        "DefaultSearchProviderAlternateURLs" = [
          "https://kagi.com/search?q={searchTerms}"
        ];
        "DefaultSearchProviderEnabled" = true;
        "DefaultSearchProviderImageURL" = "https://assets.kagi.com/v2/apple-touch-icon.png";
        "DefaultSearchProviderKeyword" = "kagi";
        "DefaultSearchProviderName" = "Kagi";
        "DefaultSearchProviderSearchURL" = "https://kagi.com/search?q={searchTerms}";
        "DefaultSearchProviderSuggestURL" = "https://kagi.com/api/autosuggest?q={searchTerms}";
        # Generative AI; these settings disable the AI features to prevent data collection
        "CreateThemesSettings" = 2;
        "DevToolsGenAiSettings" = 2;
        "GenAILocalFoundationalModelSettings" = 1;
        "HelpMeWriteSettings" = 2;
        "TabOrganizerSettings" = 2;
        # Network
        "ZstdContentEncodingEnabled" = true;
        # Password manager
        "PasswordDismissCompromisedAlertEnabled" = true;
        "PasswordLeakDetectionEnabled" = false;
        "PasswordManagerEnabled" = false;
        "PasswordSharingEnabled" = false;
        # Printing
        "PrintingPaperSizeDefault" = "iso_a4_210x297mm";
        # Related Website Sets
        "RelatedWebsiteSetsEnabled" = false;
        # Safe Browsing
        "SafeBrowsingExtendedReportingEnabled" = false;
        "SafeBrowsingProtectionLevel" = 1;
        "SafeBrowsingProxiedRealTimeChecksAllowed" = false;
        "SafeBrowsingSurveysEnabled" = false;
        # Startup, Home and New Tab Page
        "HomePageIsNewTabPage" = true;
        "HomePageLocation" = "https://${hostname}.drongo-gamma.ts.net";
        "NewTabPageLocation" = "https://${hostname}.drongo-gamma.ts.net";
        "RestoreOnStartup" = 1;
        "ShowHomeButton" = false;
      };
    };
    # TODO: Configure Microsoft Edge policy
    # - https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
    # - https://github.com/M86xKC/edge-config/blob/main/policies.json

    # - https://mozilla.github.io/policy-templates/
    firefox = {
      enable = true;
      languagePacks = [ "en-GB" "en-US" ];
      package = pkgs.firefox;
      preferences = {
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        "browser.crashReports.unsubmittedCheck.enabled" = false;
        "browser.fixup.dns_first_for_single_words" =  false;
        "browser.newtab.extensionControlled" = true;
        "browser.search.update" = true;
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.history" = true;
        "browser.urlbar.suggest.openpage" = false;
        "browser.tabs.warnOnClose" = false;
        "browser.urlbar.update2.engineAliasRefresh" = true;
        "datareporting.policy.dataSubmissionPolicyBypassNotification" = true;
        "dom.disable_window_flip" = true;
        "dom.disable_window_move_resize" = false;
        "dom.event.contextmenu.enabled" = true;
        "dom.reporting.crash.enabled" = false;
        "extensions.getAddons.showPane" = false;
        "media.gmp-gmpopenh264.enabled" = true;
        "media.gmp-widevinecdm.enabled" = true;
        "places.history.enabled" = true;
        "security.ssl.errorReporting.enabled" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
      preferencesStatus = "default";
      policies = {
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "CaptivePortal" = true;
        "Cookies" = {
          "AcceptThirdParty" = "from-visited";
          "Behavior" = "reject-tracker";
          "BehaviorPrivateBrowsing" = "reject-tracker";
          "RejectTracker" = true;
        };
        "DisableAppUpdate" = true;
        "DisableDefaultBrowserAgent" = true;
        "DisableFirefoxStudies" = true;
        "DisableFormHistory" = true;
        "DisablePocket" = true;
        "DisableProfileImport" = true;
        "DisableTelemetry" = true;
        "DisableSetDesktopBackground" = true;
        "DisplayBookmarksToolbar" = "never";
        "DisplayMenuBar" = "default-off";
        "DNSOverHTTPS" = {
          "Enabled" = false;
        };
        "DontCheckDefaultBrowser" = true;
        "EnableTrackingProtection" = {
          "Value" = false;
          "Locked" = false;
          "Cryptomining" = true;
          "EmailTracking" = true;
          "Fingerprinting" = true;
        };
        "EncryptedMediaExtensions" = {
          "Enabled" = true;
          "Locked" = true;
        };
        # Check about:support for extension/add-on ID strings.
        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };
          "support@lastpass.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/lastpass-password-manager/latest.xpi";
            installation_mode = "force_installed";
          };
          "87677a2c52b84ad3a151a4a72f5bd3c4@jetpack" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/grammarly-1/latest.xpi";
            installation_mode = "force_installed";
          };
          "gdpr@cavi.au.dk" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
            installation_mode = "force_installed";
          };
          "sponsorBlocker@ajay.app" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
            installation_mode = "force_installed";
          };
          "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
            installation_mode = "force_installed";
          };
          "easyscreenshot@mozillaonline.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/easyscreenshot/latest.xpi";
            installation_mode = "force_installed";
          };
          "search@kagi.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/kagi-search-for-firefox/latest.xpi";
            installation_mode = "force_installed";
          };
          "newtaboverride@agenedia.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/new-tab-override/latest.xpi";
            installation_mode = "force_installed";
          };
          "enterprise-policy-generator@agenedia.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/enterprise-policy-generator/latest.xpi";
            installation_mode = "force_installed";
          };
          "{2adf0361-e6d8-4b74-b3bc-3f450e8ebb69}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-mocha-blue-git/latest.xpi";
            installation_mode = "force_installed";
          };
        };
        "ExtensionUpdate" = true;
        "FirefoxHome" = {
          "Search" = true ;
          "TopSites" = false;
          "SponsoredTopSites" = false;
          "Highlights" = false;
          "Pocket" = false;
          "SponsoredPocket" = false;
          "Snippets" = false;
          "Locked" = true;
        };
        "FirefoxSuggest" = {
          "WebSuggestions" = false;
          "SponsoredSuggestions" = false;
          "ImproveSuggest" = false;
          "Locked" = true;
        };
        "FlashPlugin" = {
          "Default" = false;
        };
        "HardwareAcceleration" = true;
        "Homepage" = {
          "Locked" = false;
          "StartPage" = "previous-session";
          "URL" = "https://${hostname}.drongo-gamma.ts.net";
        };
        "NetworkPrediction" = false;
        "NewTabPage" = true;
        "NoDefaultBookmarks" = true;
        "OfferToSaveLogins" = false;
        "OverrideFirstRunPage" = "";
        "OverridePostUpdatePage" = "";
        "PasswordManagerEnabled" = false;
        "PopupBlocking" = {
          "Default" = true;
        };
        "PromptForDownloadLocation" = true;
        "SearchBar" = "unified";
        "SearchEngines" = {
          "Add" = [
            {
              "Description" = "Kagi";
              "IconURL" = "https://assets.kagi.com/v2/apple-touch-icon.png";
              "Method" = "GET";
              "Name" = "Kagi";
              "SuggestURLTemplate" = "https://kagi.com/api/autosuggest?q={searchTerms}";
              "URLTemplate" = "https://kagi.com/search?q={searchTerms}";
            }
          ];
          "Default" = "Kagi";
          "DefaultPrivate" = "Kagi";
          "Remove" = [
            "Bing"
            "eBay"
            "Google"
          ];
        };
        "SearchSuggestEnabled" = true;
        "ShowHomeButton" = false;
        "StartDownloadsInTempDirectory" = true;
        "UserMessaging" = {
          "WhatsNew" = false;
          "ExtensionRecommendations" = true;
          "FeatureRecommendations" = false;
          "UrlbarInterventions" = false;
          "SkipOnboarding" = true;
          "MoreFromMozilla" = false;
          "Locked" = false;
        };
        "UseSystemPrintDialog" = true;
      };
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
    # https://nixos.wiki/wiki/PipeWire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    # Debugging
    #  - pw-top                                            # see live stats
    #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync is "bad")
    #  - pw-metadata -n settings 0                         # see current quantums
    #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
    #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = isGamestation;
      jack.enable = false;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
        # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
        # cat /nix/store/*-wireplumber-*/share/wireplumber/main.lua.d/99-alsa-lowlatency.lua
        # cat /nix/store/*-wireplumber-*/share/wireplumber/wireplumber.conf.d/99-alsa-lowlatency.conf
        configPackages = lib.mkIf (needsLowLatencyPipewire) [
          (pkgs.writeTextDir "share/wireplumber/main.lua.d/99-alsa-lowlatency.lua" ''
              alsa_monitor.rules = {
                {
                  matches = {{{ "node.name", "matches", "*_*put.*" }}};
                  apply_properties = {
                    ["audio.format"] = "S16LE",
                    ["audio.rate"] = 48000,
                    -- api.alsa.headroom: defaults to 0
                    ["api.alsa.headroom"] = 128,
                    -- api.alsa.period-num: defaults to 2
                    ["api.alsa.period-num"] = 2,
                    -- api.alsa.period-size: defaults to 1024, tweak by trial-and-error
                    ["api.alsa.period-size"] = 512,
                    -- api.alsa.disable-batch: USB audio interface typically use the batch mode
                    ["api.alsa.disable-batch"] = false,
                    ["resample.quality"] = 4,
                    ["resample.disable"] = false,
                    ["session.suspend-timeout-seconds"] = 0,
                  },
                },
              }
            '')
        ];
      };
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
      extraConfig.pipewire."92-low-latency" = lib.mkIf (needsLowLatencyPipewire) {
        "context.properties" = {
          "default.clock.rate"          = 48000;
          "default.clock.quantum"       = 64;
          "default.clock.min-quantum"   = 64;
          "default.clock.max-quantum"   = 64;
        };
        "context.modules" = [{
          name = "libpipewire-module-rt";
          args = {
            "nice.level" = -11;
            "rt.prio" = 88;
          };
        }];
      };
      extraConfig.pipewire-pulse."92-low-latency" = lib.mkIf (needsLowLatencyPipewire) {
        "pulse.properties" = {
          "pulse.default.format" = "S16";
          "pulse.fix.format" = "S16LE";
          "pulse.fix.rate" = "48000";
          "pulse.min.frag" = "64/48000";      # 1.3ms
          "pulse.min.req" = "64/48000";       # 1.3ms
          "pulse.default.frag" = "64/48000";  # 1.3ms
          "pulse.default.req" = "64/48000";   # 1.3ms
          "pulse.max.req" = "64/48000";       # 1.3ms
          "pulse.min.quantum" = "64/48000";   # 1.3ms
          "pulse.max.quantum" = "64/48000";   # 1.3ms
        };
        "stream.properties" = {
          "node.latency" = "64/48000";        # 1.3ms
          "resample.quality" = 4;
          "resample.disable" = false;
        };
      };
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
      # Allow users in the audio group to change cpu dma latency
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
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
