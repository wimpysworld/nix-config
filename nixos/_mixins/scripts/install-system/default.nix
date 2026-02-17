{
  isISO,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  install-system = pkgs.writeShellApplication {
    name = "install-system";
    runtimeInputs = with pkgs; [
      inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default
      coreutils-full
      findutils
      gawk
      gnugrep
      git
      home-manager
      iproute2
      rsync
      sops
      util-linux
    ];
    text = builtins.readFile ./install-system.sh;
  };
in
{
  environment.systemPackages = lib.optionals isISO [ install-system ];
}
