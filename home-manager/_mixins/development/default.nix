{
  noughtyLib,
  lib,
  pkgs,
  ...
}:
let
  currentDir = ./.;
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
  dockerPurge = pkgs.writeShellApplication {
    name = "docker-purge";
    runtimeInputs = with pkgs; [
      docker
      jq
      coreutils
    ];
    text = ''
      echo "⬢ WARNING: This will stop and remove *all* Docker resources on your system."
      # shellcheck disable=SC2162
      read -p "Are you sure you want to continue? (y/N): " confirm
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
      fi
      for ID in $(docker images --format json | jq -r .ID); do
        docker stop "$(docker ps -aq --filter ancestor="$ID")" || true
        docker rmi -f "$ID" || true
      done
      for ID in $(docker ps -aq); do
        docker container kill "$ID" || true
        docker container rm "$ID" || true
      done
      docker network prune --force || true
      docker volume prune --force || true
      docker system prune --all --volumes --force || true
    '';
  };
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home = {
      packages = with pkgs; [
        dconf2nix # Nix code from Dconf files
        dockerPurge
        tokei # Modern Unix `wc` for code
      ];
    };
  };
}
