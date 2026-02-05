{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      jq
      sops
      syncthing
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = [ shellApplication ];
}
