{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Helper function to convert RGB array to comma-separated string for kmscon
  rgbToKmscon =
    colorName:
    let
      rgb = catppuccinPalette.getRGB colorName;
    in
    "${toString rgb.r},${toString rgb.g},${toString rgb.b}";
  # VTs to pre-activate at boot. Without this, logind only spawns kmscon
  # reactively when a user switches VTs, which leaves the initial TTY blank
  # on ISOs and servers until you switch away and back.
  ttyList = [
    "tty1"
    "tty2"
    "tty3"
    "tty4"
    "tty5"
    "tty6"
    "tty7"
    "tty8"
  ];
  kmsconFontSize = {
    sidious = "24";
    tanis = "18";
    felkor = "18";
    skrye = "20";
    vader = "20";
  };
  kmsconExtraConfig =
    (
      if (builtins.hasAttr host.name kmsconFontSize) then
        ''
          font-size=${kmsconFontSize.${host.name}}
        ''
      else
        ''
          font-size=16
        ''
    )
    + ''
      no-drm
      no-switchvt
      grab-scroll-up=
      grab-scroll-down=
      palette=custom
      palette-black=${rgbToKmscon "surface1"}
      palette-red=${rgbToKmscon "red"}
      palette-green=${rgbToKmscon "green"}
      palette-yellow=${rgbToKmscon "yellow"}
      palette-blue=${rgbToKmscon "blue"}
      palette-magenta=${rgbToKmscon "pink"}
      palette-cyan=${rgbToKmscon "teal"}
      palette-light-grey=${rgbToKmscon "subtext0"}
      palette-dark-grey=${rgbToKmscon "surface2"}
      palette-light-red=${rgbToKmscon "red"}
      palette-light-green=${rgbToKmscon "green"}
      palette-light-yellow=${rgbToKmscon "yellow"}
      palette-light-blue=${rgbToKmscon "blue"}
      palette-light-magenta=${rgbToKmscon "pink"}
      palette-light-cyan=${rgbToKmscon "teal"}
      palette-white=${rgbToKmscon "text"}
      palette-foreground=${rgbToKmscon "subtext1"}
      palette-background=${rgbToKmscon "base"}
      sb-size=16384
    '';
  useGeoclue = !host.is.server && !host.is.iso;

  # Use centralized VT color mapping from palette
  inherit (catppuccinPalette) vtColorMap;

  # Helper to extract RGB values for VT kernel parameters
  getRGBForVT = colorName: catppuccinPalette.getRGB colorName;

  # Generate VT kernel parameters with dynamic Catppuccin colors
  vtKernelParams =
    let
      # Get RGB values for all 16 colors
      rgbValues = map getRGBForVT vtColorMap;

      # Extract red, green, blue components separately
      reds = map (rgb: toString rgb.r) rgbValues;
      greens = map (rgb: toString rgb.g) rgbValues;
      blues = map (rgb: toString rgb.b) rgbValues;

      # Join with commas for kernel parameters
      redParams = builtins.concatStringsSep "," reds;
      greenParams = builtins.concatStringsSep "," greens;
      blueParams = builtins.concatStringsSep "," blues;
    in
    [
      "vt.default_red=${redParams}"
      "vt.default_grn=${greenParams}"
      "vt.default_blu=${blueParams}"
    ];
in
{
  boot = {
    # Catppuccin theme
    kernelParams = vtKernelParams;
  };

  console = {
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    keyMap = host.keyboard.consoleKeymap;
    packages = with pkgs; [ tamzen ];
  };

  fonts = {
    fontDir.enable = true;
    packages =
      with pkgs;
      [
        nerd-fonts.fira-code
      ]
      ++ lib.optionals (!host.is.iso) [
        noto-fonts-monochrome-emoji
        symbola
        work-sans
      ];
    fontconfig = {
      antialias = true;
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

  i18n = {
    defaultLocale = host.keyboard.locale;
    extraLocaleSettings = {
      LC_ADDRESS = host.keyboard.locale;
      LC_IDENTIFICATION = host.keyboard.locale;
      LC_MEASUREMENT = host.keyboard.locale;
      LC_MONETARY = host.keyboard.locale;
      LC_NAME = host.keyboard.locale;
      LC_NUMERIC = host.keyboard.locale;
      LC_PAPER = host.keyboard.locale;
      LC_TELEPHONE = host.keyboard.locale;
      LC_TIME = host.keyboard.locale;
    };
  };

  location = lib.mkIf useGeoclue {
    provider = "geoclue2";
  };

  services = {
    automatic-timezoned.enable = useGeoclue;
    geoclue2 = {
      enable = useGeoclue;
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://api.positon.xyz/v1/geolocate?key=test";
      submissionUrl = "https://api.positon.xyz/v2/geosubmit?key=test";
      submitData = false;
    };
    localtimed.enable = useGeoclue;
    # TODO: Does compiling without fbterm help by odd sized displays?
    # - https://github.com/Aetf/kmscon/issues/18#issuecomment-612003371

    kmscon = {
      autologinUser = if host.is.iso then "nixos" else null;
      enable = true;
      hwRender = false;
      fonts = [
        {
          name = "FiraCode Nerd Font Mono";
          package = pkgs.nerd-fonts.fira-mono;
        }
      ];
      extraConfig = kmsconExtraConfig;
      useXkbConfig = true;
    };
    xserver.xkb.layout = host.keyboard.layout;
  };

  # Override the upstream kmsconvt@ template to add boot ordering and a getty
  # fallback. This drop-in applies to all instances (including those spawned
  # reactively by logind via the autovt@ alias).
  # Reference: https://github.com/noughtylinux/config/blob/main/system-manager/kmscon.nix
  #
  # Pre-activate kmscon on all VTs at boot. NixOS's wantedBy creates raw
  # symlinks without consulting DefaultInstance, so wantedBy on a bare template
  # (kmsconvt@) produces getty.target.wants/kmsconvt@.service which systemd
  # ignores. Explicit instances ensure the correct symlinks are created:
  # getty.target.wants/kmsconvt@ttyN.service -> ../kmsconvt@.service
  # This prevents the blank-screen problem on ISOs and servers where the
  # reactive autovt@ mechanism does not fire until a VT switch occurs.
  systemd.services = {
    "kmsconvt@" = {
      after = [
        "systemd-user-sessions.service"
        "plymouth-quit-wait.service"
        "getty-pre.target"
        "dbus.service"
        "systemd-localed.service"
      ];
      before = [ "getty.target" ];
      conflicts = [ "getty@%i.service" ];
      onFailure = [ "getty@%i.service" ];
      unitConfig = {
        IgnoreOnIsolate = true;
        ConditionPathExists = "/dev/tty0";
      };
      serviceConfig = {
        Type = "idle";
      };
    };
  }
  // builtins.listToAttrs (
    map (tty: {
      name = "kmsconvt@${tty}";
      value = {
        wantedBy = [ "getty.target" ];
      };
    }) ttyList
  );

  # Prevent "Failed to open /etc/geoclue/conf.d/:" errors
  systemd.tmpfiles.rules = [
    "d /etc/geoclue/conf.d 0755 root root"
  ];

  time = {
    timeZone = lib.mkIf host.is.server "UTC";
  };
}
