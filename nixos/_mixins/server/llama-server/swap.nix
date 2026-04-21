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
  listenPort = 8080;

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

  embeddingMembers = lib.mapAttrsToList (_role: model: model.publicName) (
    lib.filterAttrs (_role: model: model.isEmbedding) selectedRuntime.selectedRuntimeModels
  );

  generationMembers = lib.mapAttrsToList (_role: model: model.publicName) (
    lib.filterAttrs (_role: model: !model.isEmbedding) selectedRuntime.selectedRuntimeModels
  );

  launchLlamaServer = pkgs.writeShellApplication {
    name = "llama-server-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      llamaPackage
    ];
    text = ''
      modelPathPattern="$1"
      port="$2"
      shift 2

      snapshotRoot="''${modelPathPattern%/*/*}"
      modelFileName="''${modelPathPattern##*/}"

      mapfile -t modelPathMatches < <(
        find "$snapshotRoot" -mindepth 2 -maxdepth 2 -name "$modelFileName" -print
      )

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

  mkModelConfig = model: {
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

in
{
  config = lib.mkIf isInference {
    services.llama-swap = {
      enable = true;
      package = pkgs.llama-swap;
      port = listenPort;
      settings = llamaSwapSettings;
    };

    systemd.services.llama-swap = {
      requires = [ "llama-models-preseed.service" ];
      after = [ "llama-models-preseed.service" ];
      environment = {
        HOME = "%S/llama-swap";
        TMPDIR = "%t/llama-swap";
        XDG_CACHE_HOME = "%C/llama-swap";
        XDG_CONFIG_HOME = "%S/llama-swap";
        XDG_DATA_HOME = "%S/llama-swap";
      }
      // lib.optionalAttrs (accel == "vulkan") {
        LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
        XDG_DATA_DIRS = "/run/opengl-driver/share:/run/opengl-driver-32/share";
      };
      serviceConfig = {
        CacheDirectory = "llama-swap";
        RuntimeDirectory = "llama-swap";
        StateDirectory = "llama-swap";
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
    };
  };
}
