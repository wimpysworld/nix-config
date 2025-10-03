{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      which
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = [ shellApplication ];
}
