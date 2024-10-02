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
      "${config.home.homeDirectory}/.lima/_templates/blackace.yaml".text = builtins.readFile ./blackace.yaml;
      "${config.home.homeDirectory}/.lima/_templates/defender.yaml".text = builtins.readFile ./defender.yaml;
      "${config.home.homeDirectory}/.lima/_templates/fighter.yaml".text = builtins.readFile ./fighter.yaml;
    };
    packages = with pkgs; [ shellApplication ];
  };
  programs.fish.shellAliases = {
    create-blackace = "lima-create blackace";
    create-defender = "lima-create defender";
    create-fighter = "lima-create fighter";
    blackace = "limactl shell blackace";
    defender = "limactl shell defender";
    fighter = "limactl shell fighter";
  };
}
