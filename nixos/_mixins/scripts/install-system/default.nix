{
  isISO,
  inputs,
  pkgs,
  platform,
  ...
}:
let
  install-system = pkgs.writeShellApplication {
    name = "install-system";
    runtimeInputs = with pkgs; [
      inputs.disko.packages.${platform}.default
      keyutils
      gawk
      gnugrep
      git
      home-manager
      iproute2
      rsync
      util-linux
      uutils-coreutils-noprefix
      uutils-findutils
    ];
    text = builtins.readFile ./install-system.sh;
  };
in
{
  environment.systemPackages = with pkgs; lib.optionals isISO [ install-system ];
}
