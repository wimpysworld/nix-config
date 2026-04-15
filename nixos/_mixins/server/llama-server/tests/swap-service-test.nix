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
  swapConfig = inferenceEval.config.services.llama-swap;
  modelNames = builtins.attrNames swapConfig.settings.models;
  groupNames = builtins.attrNames swapConfig.settings.groups;
in
assert inferenceEval.config.systemd.services ? llama-swap;
assert inferenceEval.config.systemd.services ? llama-models-preseed;
assert !(nonInferenceEval.config.systemd.services ? llama-swap);
assert swapConfig.enable;
assert swapConfig.package == inferenceEval.pkgs.llama-swap;
assert swapConfig.port == 8080;
assert service.serviceConfig.Type == "exec";
assert service.serviceConfig.DynamicUser;
assert service.serviceConfig.Restart == "on-failure";
assert service.serviceConfig.RestartSec == 3;
assert builtins.elem "network.target" service.after;
assert lib.hasInfix "--listen :8080" service.serviceConfig.ExecStart;
assert builtins.elem inferenceEval.pkgs.llama-swap inferenceEval.config.environment.systemPackages;
assert builtins.elem "qwen3-coder-next" modelNames;
assert builtins.elem "qwen3-embedding-4b" modelNames;
assert builtins.elem "embedding" groupNames;
assert builtins.elem "generation" groupNames;
assert builtins.elem "llama-models-preseed.service" service.requires;
assert builtins.elem "llama-models-preseed.service" service.after;
true
