{
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
  };
  kmsconExtraConfig =
    if (builtins.hasAttr hostname kmsconFontSize) then
      ''font-size=${kmsconFontSize.${hostname}}''
    else
      ''font-size=14'';
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
    kmscon = lib.mkIf isInstall {
      enable = true;
      hwRender = true;
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
