{ desktop, pkgs, ... }: {
  imports = [
    ../services/cups.nix
    ../services/flatpak.nix
    ../services/sane.nix
    (./. + "/${desktop}.nix")
  ];

  boot.kernelParams = [ "quiet" ];
  boot.plymouth.enable = true;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "UbuntuMono"]; })
      joypixels
      liberation_ttf
      ubuntu_font_family
      work-sans
    ];

    # use fonts specified by user rather than default ones
    enableDefaultFonts = false;

    fontconfig = {
      antialias = true;
      cache32Bit = true;
      defaultFonts = {
        serif = [ "Work Sans" "Joypixels" ];
        sansSerif = [ "Work Sans" "Joypixels" ];
        monospace = [ "FiraCode Nerd Font Mono" ];
        emoji = [ "Joypixels" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "hintslight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    unstable.chromium
  ];

  programs = {
    dconf.enable = true;
    chromium = {
      enable = true;
      extensions = [
      	"hdokiejnpimakedhajhdlcegeplioahd" # LastPass
      ];
      extraOpts = {
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "BuiltInDnsClientEnabled" = false;
        "​DeviceMetricsReportingEnabled" = true;
        "​ReportDeviceCrashReportInfo" = false;
        "PasswordManagerEnabled" = false;
        "​SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "en-GB"
          "en-US"
        ];
        "VoiceInteractionHotwordEnabled" = false;
      };
    };
    firefox = {
      enable = false;
    };
  };

  # Accept the joypixels license
  nixpkgs.config.joypixels.acceptLicense = true;
  
  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
}
