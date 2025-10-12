{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
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
  precommitSetup = pkgs.writeShellApplication {
    name = "pre-commit-setup";
    runtimeInputs = with pkgs; [
      nixpkgs-review
      pre-commit
    ];
    text = builtins.readFile ./pre-commit-setup.sh;
  };

in
{
  home = {
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/.local/go";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
    };
    packages =
      with pkgs;
      [
        dockerPurge
        precommitSetup
        tokei # Modern Unix `wc` for code
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        waveboxXdgOpen # Integrate Wavebox with Slack, GitHub, Auth, etc.
      ];
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
      #gh_token = {
      #  sopsFile = ../../../secrets/github.yaml;
      #};
      #gh_read_only = {
      #  sopsFile = ../../../secrets/github.yaml;
      #};
    };
  };
}
