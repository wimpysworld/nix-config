{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      procps
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (noughtyLib.userHasTag "developer") { home.packages = [ shellApplication ]; }
