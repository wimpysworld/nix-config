{ config, pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      gawk
      gnused
      lima-bin
      procps
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home = {
    file = {
      "${config.home.homeDirectory}/.lima/_templates/ubuntu-22.yml".text = builtins.readFile ./ubuntu-22.yml;
      "${config.home.homeDirectory}/.lima/_templates/ubuntu-24.yml".text = builtins.readFile ./ubuntu-24.yml;
    };
    packages = with pkgs; [ shellApplication ];
  };
  programs.fish.shellAliases = {
    create-defender = "lima-create defender";
    create-fighter = "lima-create fighter";
    defender = "limactl shell defender";
    fighter = "limactl shell fighter";
  };
}
