{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment.systemPackages = with pkgs; [
    (davinci-resolve.override {
      studioVariant = true;
    })
    shotcut
  ];
}
