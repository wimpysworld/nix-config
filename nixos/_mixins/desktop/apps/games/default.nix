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
    ];
  };
}
