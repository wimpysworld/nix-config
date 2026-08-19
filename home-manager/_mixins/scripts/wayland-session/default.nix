{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [
      veila
    ]
    ++ (with pkgs; [
      bluez
      coreutils
      inetutils
      playerctl
      procps
    ]);
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];
}
