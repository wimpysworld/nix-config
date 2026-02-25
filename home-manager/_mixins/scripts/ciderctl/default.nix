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
      bc
      curl
      jq
      coreutils
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (noughtyLib.hostHasTag "studio") { home.packages = with pkgs; [ shellApplication ]; }
