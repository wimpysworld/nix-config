{
  config,
  inputs,
  lib,
  pkgs,
  stateVersion,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  # Derive Apple locale strings from the keyboard locale.
  # "en_GB.UTF-8" -> "en_GB" (strip encoding suffix)
  # "en_GB" -> "en-GB" (Apple language tag uses hyphens)
  appleLocale = lib.head (lib.splitString "." host.keyboard.locale);
  appleLanguage = builtins.replaceStrings [ "_" ] [ "-" ] appleLocale;
in
{
  imports = [
    # Common configuration shared with nixos
    ../common
    ../lib/noughty
    inputs.determinate.darwinModules.default
    inputs.mac-app-util.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.nix-index-database.darwinModules.nix-index
    ./_mixins/desktop
    ./_mixins/features
  ];

  environment = {
    shells = [ pkgs.fish ];
    # Darwin-specific packages; common packages are in ../common
    systemPackages = with pkgs; [
      m-cli
      mas
      nh
      plistwatch
    ];

    variables = {
      SHELL = "${pkgs.fish}/bin/fish";
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };

  nix-homebrew = {
    enable = true;
    enableRosetta = if (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") then true else false;
    autoMigrate = true;
    user = "${username}";
    mutableTaps = true;
  };

  # Determinate Nix darwin module configuration
  determinateNix = {
    enable = true;
    # Enable native Linux builder (aarch64-linux, x86_64-linux) via macOS
    # Virtualization framework. Access is gated - request via FlakeHub.
    # Note: external-builders is managed by determinateNixd; setting it in
    # customSettings is blocked by the module (disallowedOptions).
    determinateNixd.builder.state = "enabled";
    customSettings = {
      experimental-features = "nix-command flakes";
      extra-experimental-features = "parallel-eval";
      # Disable global registry
      flake-registry = "";
      lazy-trees = true;
      eval-cores = 0; # Enable parallel evaluation across all cores
      # Workaround for NixOS/nix#1254; avoids HTTP/2 framing errors from CDN servers
      http2 = false;
      # Increase download parallelism for faster substitution
      max-substitution-jobs = 64;
      http-connections = 128;
      connect-timeout = 10;
      # Allow wheel users to set client-side Nix options (e.g. netrc-file
      # for FlakeHub Cache authentication via fh apply).
      trusted-users = [
        "root"
        "@admin"
      ];
      warn-dirty = false;
    };
  };

  # Prevent audio stutter and UI jank during builds.
  # The daemon's scheduling policy propagates to all build processes.
  nix.daemonProcessType = "Background";
  nix.daemonIOLowPriority = true;

  programs = {
    fish = {
      shellAliases = {
        nano = "micro";
      };
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    info.enable = false;
  };

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = "${username}";
    inherit stateVersion;
    defaults = {
      CustomUserPreferences = {
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.controlcenter" = {
          BatteryShowPercentage = true;
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.finder" = {
          _FXSortFoldersFirst = true;
          FXDefaultSearchScope = "SCcf"; # Search current folder by default
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = false;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
        };
        # Prevent Photos from opening automatically
        "com.apple.ImageCapture".disableHotPlug = true;
        "com.apple.screencapture" = {
          location = "~/Pictures/Screenshots";
          type = "png";
        };
        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 0;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
        # Turn on app auto-update
        "com.apple.commerce".AutoUpdate = true;
        NSGlobalDomain = {
          AppleLanguages = [ appleLanguage ];
          AppleLocale = appleLocale;
        };
      };
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = true;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        # Disable switching to Space with open windows when switching apps
        AppleSpacesSwitchOnActivate = false;
      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = false;
      };
      dock = {
        orientation = "left";
        # TODO: Make this user-specific
        persistent-apps = [
          "/Applications/Orion.app"
          "/Applications/Nix Apps/Brave Browser.app"
          "/Users/${username}/Applications/Home Manager Apps/Telegram.app"
          "/Users/${username}/Applications/Home Manager Apps/Discord.app"
          "/Users/${username}/Applications/Home Manager Apps/Halloy.app"
          "/Users/${username}/Applications/Home Manager Apps/Visual Studio Code.app"
          "/Users/${username}/Applications/Home Manager Apps/GitKraken.app"
          "/Users/${username}/Applications/Home Manager Apps/Kitty.app"
          "/System/Applications/Music.app"
          "/Applications/Heynote.app"
          "/Users/${username}/Applications/Home Manager Apps/Joplin.app"
          "/System/Applications/Apps.app"
        ];
        show-recents = false;
        tilesize = 48;
        # Disable hot corners
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        # Mission Control and Spaces preferences
        mru-spaces = false; # Disable automatic rearranging of Spaces
        expose-animation-duration = 0.1; # Faster Mission Control animations
        expose-group-apps = false; # Don't group windows by application in Mission Control
      };
      finder = {
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      menuExtraClock = {
        ShowAMPM = false;
        ShowDate = 1; # Always
        ShowSeconds = false;
        Show24Hour = true;
      };
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 300;
      };
      smb.NetBIOSName = host.name;
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true; # enable two finger right click
      };
    };
  };
}
