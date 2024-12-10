{
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    packages = with pkgs; [
      (defold.override {
        uiScale = "1.25";
      })
      pico8
    ];
  };
}
