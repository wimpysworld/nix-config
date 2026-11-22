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
          nixpkgs.overlays = builtins.attrValues flake.overlays;
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
  inherit (swapConfig.settings) models;
  matchesVulkanBackend =
    packageName: name:
    let
      package = inferenceEval.pkgs.${packageName}.override { vulkanSupport = true; };
      command = builtins.unsafeDiscardStringContext (lib.getExe' package "llama-server");
    in
    package.pname == packageName && lib.hasInfix command models.${name}.cmd;
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
assert service.serviceConfig.CacheDirectory == "llama-swap";
assert service.serviceConfig.RuntimeDirectory == "llama-swap";
assert service.serviceConfig.StateDirectory == "llama-swap";
assert builtins.elem "network.target" service.after;
assert lib.hasInfix "--listen=${swapConfig.listenAddress}:${toString swapConfig.port}"
  service.serviceConfig.ExecStart;
assert service.environment.HOME == "%S/llama-swap";
assert service.environment.TMPDIR == "%t/llama-swap";
assert service.environment.XDG_CACHE_HOME == "%C/llama-swap";
assert service.environment.XDG_CONFIG_HOME == "%S/llama-swap";
assert service.environment.XDG_DATA_HOME == "%S/llama-swap";
assert service.environment.LD_LIBRARY_PATH == "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
assert service.environment.XDG_DATA_DIRS == "/run/opengl-driver/share:/run/opengl-driver-32/share";
assert builtins.elem inferenceEval.pkgs.llama-swap inferenceEval.config.environment.systemPackages;
assert matchesVulkanBackend "llama-cpp-inkling" "inkling-2-mini";
assert matchesVulkanBackend "llama-cpp-inkling" "qwen3.8-27b";
assert matchesVulkanBackend "llama-cpp" "gemma4-e4b";
assert matchesVulkanBackend "llama-cpp" "qwen3-embedding-0.6b";
assert lib.hasInfix "Mainline_Support/" models.inkling-2-mini.cmd;
assert builtins.elem "embedding" groupNames;
assert builtins.elem "generation" groupNames;
assert builtins.elem "llama-models-preseed.service" service.requires;
assert builtins.elem "llama-models-preseed.service" service.after;
assert !(nonInferenceEval.config.systemd.services.llama-swap.environment or { } ? HOME);
assert !(nonInferenceEval.config.systemd.services.llama-swap.environment or { } ? XDG_DATA_DIRS);
true
