{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ shellApplication ];
  programs.fish.shellAliases = {
    build-host = "nh-host build";
    switch-host = "nh-host switch";
  };
}
