{
  catppuccinPalette,
  hostname,
  isISO,
  isServer,
  lib,
  pkgs,
  ...
}:
let
  consoleKeymap = "uk";
  locale = "en_GB.UTF-8";
  xkbLayout = "gb";
  # Helper function to convert RGB array to comma-separated string for kmscon
  rgbToKmscon =
    colorName:
    let
      rgb = catppuccinPalette.getRGB colorName;
    in
    "${toString rgb.r},${toString rgb.g},${toString rgb.b}";
  kmsconFontSize = {
    sidious = "24";
    tanis = "18";
    vader = "20";
  };
  kmsconExtraConfig =
    (
      if (builtins.hasAttr hostname kmsconFontSize) then
        ''
          font-size=${kmsconFontSize.${hostname}}
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
  useGeoclue = !isServer;
in
{
  boot = {
    # Catppuccin theme
    kernelParams = [
      "vt.default_red=30,243,166,249,137,245,148,186,88,243,166,249,137,245,148,166"
      "vt.default_grn=30,139,227,226,180,194,226,194,91,139,227,226,180,194,226,173"
      "vt.default_blu=46,168,161,175,250,231,213,222,112,168,161,175,250,231,213,200"
    ];
  };

  console = {
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    keyMap = consoleKeymap;
    packages = with pkgs; [ tamzen ];
  };

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
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
    defaultLocale = locale;
    extraLocaleSettings = {
      LC_ADDRESS = locale;
      LC_IDENTIFICATION = locale;
      LC_MEASUREMENT = locale;
      LC_MONETARY = locale;
      LC_NAME = locale;
      LC_NUMERIC = locale;
      LC_PAPER = locale;
      LC_TELEPHONE = locale;
      LC_TIME = locale;
    };
  };

  location = {
    provider = "geoclue2";
  };

  services = {
    automatic-timezoned.enable = useGeoclue;
    geoclue2 = {
      enable = true;
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://api.positon.xyz/v1/geolocate?key=test";
      submissionUrl = "https://api.positon.xyz/v2/geosubmit?key=test";
      submitData = false;
    };
    localtimed.enable = useGeoclue;
    # TODO: Does compiling without fbterm help by odd sized displays?
    # - https://github.com/Aetf/kmscon/issues/18#issuecomment-612003371

    kmscon = {
      autologinUser = if isISO then "nixos" else null;
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
    xserver.xkb.layout = xkbLayout;
  };

  # Prevent "Failed to open /etc/geoclue/conf.d/:" errors
  systemd.tmpfiles.rules = [
    "d /etc/geoclue/conf.d 0755 root root"
  ];

  time = {
    hardwareClockInLocalTime = true;
    timeZone = lib.mkIf isServer "UTC";
  };
}
