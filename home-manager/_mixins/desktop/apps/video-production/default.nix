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
  home.packages = with pkgs; [
    (davinci-resolve.override {
      studioVariant = true;
    })
    shotcut
  ];
}
