{
  config,
  inputs,
  pkgs,
  ...
}:
let
  # https://github.com/numtide/nix-ai-tools
  aiPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.crush
    inputs.nix-ai-tools.packages.${pkgs.system}.spec-kit
  ];
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
  home = {
    packages = [
      dockerPurge
    ]
    ++ aiPackages;
  };

  # https://dl.thalheim.io/
  sops = {
    secrets = {
      act-env = {
        path = "${config.home.homeDirectory}/.config/act/secrets";
        sopsFile = ../../../secrets/act.yaml;
        mode = "0660";
      };
      cg-repos = {
        path = "${config.home.homeDirectory}/.config/cg-repos";
        sopsFile = ../../../secrets/cg-repos.yaml;
        mode = "0644";
      };
    };
  };
}
