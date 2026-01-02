{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # https://github.com/numtide/nix-ai-tools
  aiPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.crush
    inputs.nix-ai-tools.packages.${pkgs.system}.spec-kit
  ];
  waveboxXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      {
        case = "^https?://accounts.google.com";
        command = "wavebox";
      }
      {
        case = "^https?://github.com/login/device";
        command = "wavebox";
      }
      {
        case = "^https?://auth.chainguard.dev/activate";
        command = "wavebox";
      }
      {
        case = "^https?://issuer.enforce.dev";
        command = "wavebox";
      }
    ];
  };
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
    ++ lib.optionals pkgs.stdenv.isLinux [
      waveboxXdgOpen # Integrate Wavebox with Slack, GitHub, Auth, etc.
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
