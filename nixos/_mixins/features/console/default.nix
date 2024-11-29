{
  config,
  desktop,
  hostname,
  isInstall,
  lib,
  pkgs,
  ...
}:
let
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
        font-size=14
        ''
    )
    + ''
      no-drm
      no-switchvt
      grab-scroll-up=
      grab-scroll-down=
      palette=custom
      palette-black=69,71,90
      palette-red=243,139,168
      palette-green=166,227,161
      palette-yellow=249,226,175
      palette-blue=137,180,250
      palette-magenta=245,194,231
      palette-cyan=148,226,213
      palette-light-grey=127,132,156
      palette-dark-grey=88,91,112
      palette-light-red=243,139,168
      palette-light-green=166,227,161
      palette-light-yellow=249,226,175
      palette-light-blue=137,180,250
      palette-light-magenta=245,194,231
      palette-light-cyan=148,226,213
      palette-white=205,214,244
      palette-foreground=166,173,200
      palette-background=30,30,46
      sb-size=10240
    '';
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

  catppuccin = {
    accent = "blue";
    flavor = "mocha";
  };

  console = {
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    packages = with pkgs; [ tamzen ];
  };

  services = {
    # TODO: Build from this patch branch that has mouse support
    # - https://github.com/MacSlow/kmscon/tree/add-kmscon.conf-manpage
    # - https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/km/kmscon/package.nix
    # TODO: Replace `login -p` with maybe `fish -l`
    # TODO: Is this DRM patch helpful?
    # - https://github.com/Aetf/kmscon/pull/66
    # TODO: Does compiling without fbterm help by odd sized displays?
    # - https://github.com/Aetf/kmscon/issues/18#issuecomment-612003371
    kmscon = lib.mkIf isInstall {
      enable = true;
      hwRender = false;
      fonts = [
        {
          name = "FiraCode Nerd Font Mono";
          package = pkgs.nerdfonts.override {
            fonts = [
              "FiraCode"
              "NerdFontsSymbolsOnly"
            ];
          };
        }
      ];
      extraConfig = kmsconExtraConfig;
    };
  };
}
