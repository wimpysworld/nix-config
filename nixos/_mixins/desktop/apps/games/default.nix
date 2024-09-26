{
  inputs,
  isInstall,
  isWorkstation,
  lib,
  pkgs,
  platform,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor && isInstall && isWorkstation) {
  environment = {
    systemPackages = [
      inputs.antsy-alien-attack-pico.packages.${platform}.default
      (pkgs.defold.override {
        uiScale = "1.25";
      })
      pkgs.pico8
    ];
  };
}
