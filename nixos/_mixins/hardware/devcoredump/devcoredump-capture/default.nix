{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    gnused
    systemd
    util-linux
    zstd
  ];
  text = builtins.readFile ./${name}.sh;
}
