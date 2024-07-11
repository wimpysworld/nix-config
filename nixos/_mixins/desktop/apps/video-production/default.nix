{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "sidious"
    "tanis"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment.systemPackages = with pkgs; [
    davinci-resolve
    shotcut
  ];
}
