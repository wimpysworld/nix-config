{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      uutils-coreutils-noprefix
      hueadm
      obs-cli
      procps
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = with pkgs; [ shellApplication ];
}
