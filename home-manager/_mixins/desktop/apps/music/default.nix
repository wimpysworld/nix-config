{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  # Conditional to prevent non-redistributable local packages being
  # evaluated in CI
  isCI = builtins.getEnv "CI" == "true";
in
lib.mkIf (builtins.elem username installFor) {
  home = {
    packages = with pkgs; [
      (lib.mkIf (!isCI) cider)
      youtube-music
    ];
  };
}
