{ lib }:
let
  flake = builtins.getFlake (toString ../../../../../.);
  inherit (flake.inputs) nixpkgs;

  evalFor =
    {
      hostTags,
      hostVramGiB,
      acceleration ? null,
    }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../../../../lib/noughty
        {
          system.stateVersion = "25.11";
          noughty.host = {
            name = "testhost";
            kind = "computer";
            platform = "x86_64-linux";
            gpu.compute = {
              inherit acceleration;
              vram = hostVramGiB;
            };
            tags = hostTags;
          };
        }
        ../default.nix
      ];
    };

  inferenceEval = evalFor {
    acceleration = "vulkan";
    hostTags = [ "inference" ];
    hostVramGiB = 96;
  };

  nonInferenceEval = evalFor {
    acceleration = "vulkan";
    hostTags = [ ];
    hostVramGiB = 96;
  };

  service = inferenceEval.config.systemd.services.llama-swap;
  modelNames = builtins.fromJSON service.environment.LLAMA_SWAP_MODELS_JSON;
  groupNames = builtins.fromJSON service.environment.LLAMA_SWAP_GROUPS_JSON;
in
assert inferenceEval.config.systemd.services ? llama-swap;
assert inferenceEval.config.systemd.services ? llama-models-preseed;
assert !(nonInferenceEval.config.systemd.services ? llama-swap);
assert service.serviceConfig.Type == "simple";
assert service.serviceConfig.User == "root";
assert service.serviceConfig.Restart == "on-failure";
assert service.serviceConfig.RestartSec == "10s";
assert builtins.elem "network-online.target" service.after;
assert builtins.elem "network-online.target" service.wants;
assert lib.hasInfix "--listen 0.0.0.0:8080" service.serviceConfig.ExecStart;
assert builtins.elem inferenceEval.pkgs.llama-swap inferenceEval.config.environment.systemPackages;
assert builtins.elem "qwen3-coder-next" modelNames;
assert builtins.elem "qwen3-embedding-4b" modelNames;
assert builtins.elem "embedding" groupNames;
assert builtins.elem "generation" groupNames;
assert service.environment.LLAMA_SWAP_LOCAL_ONLY == "true";
assert builtins.elem "llama-models-preseed.service" service.requires;
assert builtins.elem "llama-models-preseed.service" service.after;
true
