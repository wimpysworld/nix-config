{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ 
      ffmpeg
      gnugrep
      kmod
      procps
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = with pkgs; [ shellApplication ];
}
