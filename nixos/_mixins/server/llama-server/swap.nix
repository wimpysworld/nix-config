{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isInference = noughtyLib.hostHasTag "inference";
  accel = host.gpu.compute.acceleration;

  llamaPackage =
    if accel == "cuda" then
      pkgs.llama-cpp.override {
        cudaSupport = true;
        rocmSupport = false;
      }
    else if accel == "rocm" then
      pkgs.llama-cpp.override {
        rocmSupport = true;
        cudaSupport = false;
      }
    else if accel == "vulkan" then
      pkgs.llama-cpp.override {
        vulkanSupport = true;
      }
    else
      pkgs.llama-cpp;

  runtime = import ./runtime.nix { inherit lib; };
  selectedRuntime = runtime.mkRuntime {
    acceleration = accel;
    hostVramGiB = host.gpu.compute.vram or 0;
  };

  listenAddress = "0.0.0.0:8080";
  yamlFormat = pkgs.formats.yaml { };

  embeddingMembers = lib.mapAttrsToList (
    _role: model: model.publicName
  ) (lib.filterAttrs (_role: model: model.isEmbedding) selectedRuntime.selectedRuntimeModels);

  generationMembers = lib.mapAttrsToList (
    _role: model: model.publicName
  ) (lib.filterAttrs (_role: model: !model.isEmbedding) selectedRuntime.selectedRuntimeModels);

  launchLlamaServer = pkgs.writeShellApplication {
    name = "llama-server-launch";
    runtimeInputs = [
      pkgs.coreutils
      llamaPackage
    ];
    text = ''
      modelPathPattern="$1"
      port="$2"
      shift 2

      shopt -s nullglob
      modelPathMatches=($modelPathPattern)
      shopt -u nullglob

      if [[ "''${#modelPathMatches[@]}" -ne 1 ]]; then
        printf 'Error: expected one model path for pattern %s, got %s\n' \
          "$modelPathPattern" "''${#modelPathMatches[@]}" >&2
        exit 1
      fi

      modelPath="$(readlink -f "''${modelPathMatches[0]}")"

      exec ${lib.getExe' llamaPackage "llama-server"} \
        --port "$port" \
        -m "$modelPath" \
        "$@"
    '';
  };

  mkModelConfig =
    model: {
      cmd = ''
        ${lib.getExe launchLlamaServer} '${model.resolvedPrimaryPathPattern}' ''${PORT} ${lib.escapeShellArgs model.runtimeArgs}
      '';
      metadata = {
        inherit (model)
          hfRepo
          modelRef
          role
          ;
      };
      name = model.publicName;
    };

  llamaSwapModels = builtins.listToAttrs (
    lib.mapAttrsToList (_role: model: {
      name = model.publicName;
      value = mkModelConfig model;
    }) selectedRuntime.selectedRuntimeModels
  );

  llamaSwapSettings = {
    globalTTL = 0;
    healthCheckTimeout = 500;
    models = llamaSwapModels;
    startPort = 10001;
    groups =
      (lib.optionalAttrs (embeddingMembers != [ ]) {
        embedding = {
          exclusive = false;
          members = embeddingMembers;
          swap = false;
        };
      })
      // (lib.optionalAttrs (generationMembers != [ ]) {
        generation = {
          exclusive = false;
          members = generationMembers;
          swap = true;
        };
      });
  };

  llamaSwapConfig = yamlFormat.generate "llama-swap.yaml" llamaSwapSettings;
in
{
  config = lib.mkIf isInference {
    systemd.services.llama-swap = {
      description = "Host-local llama-swap model router";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [ "llama-models-preseed.service" ];
      after = [
        "network-online.target"
        "llama-models-preseed.service"
      ];
      environment = {
        LLAMA_SWAP_CONFIG = "${llamaSwapConfig}";
        LLAMA_SWAP_GROUPS_JSON = builtins.toJSON (builtins.attrNames llamaSwapSettings.groups);
        LLAMA_SWAP_LISTEN = listenAddress;
        LLAMA_SWAP_LOCAL_ONLY = "true";
        LLAMA_SWAP_MODELS_JSON = builtins.toJSON (builtins.attrNames llamaSwapSettings.models);
      };
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.llama-swap)
          "--config"
          "${llamaSwapConfig}"
          "--listen"
          listenAddress
        ];
        Restart = "on-failure";
        RestartSec = "10s";
        Type = "simple";
        User = "root";
      };
    };
  };
}
