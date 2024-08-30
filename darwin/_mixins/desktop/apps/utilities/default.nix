{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
    grandperspective
    keka
    stats
    utm
  ];

  homebrew = {
    casks = [ "balenaetcher" ];
  };
}
