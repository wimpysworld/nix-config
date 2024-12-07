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
  # Conditional to prevent non-redistributable local packages being
  # evaluated in CI
  isCI = builtins.getEnv "CI" == "true";
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    packages = with pkgs; [
      (defold.override {
        uiScale = "1.25";
      })
      (lib.mkIf (!isCI) pico8)
    ];
  };
}
