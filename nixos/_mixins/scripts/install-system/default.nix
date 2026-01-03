{
  isISO,
  inputs,
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
      keyutils
      rsync
      util-linux
    ];
    text = builtins.readFile ./install-system.sh;
  };
in
{
  environment.systemPackages = with pkgs; lib.optionals isISO [ install-system ];
}
