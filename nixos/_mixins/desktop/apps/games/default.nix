{
  inputs,
  isInstall,
  isWorkstation,
  lib,
  platform,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor && isInstall && isWorkstation) {
  environment = {
    systemPackages = with inputs; [ antsy-alien-attack-pico.packages.${platform}.default ];
  };
}
