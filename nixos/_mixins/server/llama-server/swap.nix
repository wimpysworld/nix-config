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
      pkgs.llama-cpp.override { vulkanSupport = true; }
    else
      pkgs.llama-cpp;
  llamaServer = lib.getExe' llamaPackage "llama-server";

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
    text = ''
      snapshotRoot="$1"
      revision="$2"
      primaryPath="$3"
      server="$4"
      port="$5"
      shift 5
      projectorRelativePath=""
      if [[ "''${1:-}" == --mmproj ]]; then
        projectorRelativePath="$2"
        shift 2
      fi

      if [[ "$revision" != '*' ]]; then
        modelPath="$snapshotRoot/$revision/$primaryPath"
      else
        mainRevision=""
        mainRef="$snapshotRoot/../refs/main"
        if [[ -f "$mainRef" && -r "$mainRef" ]]; then
          mainRevision="$(<"$mainRef")" || mainRevision=""
        fi
        shopt -s nullglob
        modelPathMatches=()
        for candidate in "$snapshotRoot"/*/"$primaryPath"; do
          snapshotPath="''${candidate%/"$primaryPath"}"
          if [[ ! -f "$candidate" ||
            ( -n "$projectorRelativePath" && ! -f "$snapshotPath/$projectorRelativePath" ) ]]; then
            continue
          fi
          if [[ "$snapshotPath" == "$snapshotRoot/$mainRevision" ]]; then
            modelPathMatches=("$candidate")
            break
          fi
          modelPathMatches+=("$candidate")
        done
        if [[ "''${#modelPathMatches[@]}" -ne 1 ]]; then
          printf 'Error: expected one model path for pattern %s (projector: %s), got %s\n' \
            "$snapshotRoot/*/$primaryPath" "''${projectorRelativePath:-none}" "''${#modelPathMatches[@]}" >&2
          exit 1
        fi
        modelPath="''${modelPathMatches[0]}"
      fi

      if [[ ! -f "$modelPath" ]]; then
        printf 'Error: model file is missing: %s\n' "$modelPath" >&2
        exit 1
      fi

      if [[ -n "$projectorRelativePath" ]]; then
        projectorPath="''${modelPath%/"$primaryPath"}/$projectorRelativePath"
        if [[ ! -f "$projectorPath" ]]; then
          printf 'Error: projector file is missing: %s\n' "$projectorPath" >&2
          exit 1
        fi
        set -- --mmproj "$projectorPath" "$@"
      fi

      # Keep the snapshot path so llama.cpp can find sibling shards.
      exec "$server" --port "$port" -m "$modelPath" "$@"
    '';
  };

  mkModelConfig =
    model:
    let
      inherit (model.download) projectorPath;
      modelArgs =
        lib.optionals (projectorPath != null) [
          "--mmproj"
          projectorPath
        ]
        ++ model.runtimeArgs;
    in
    {
      cmd = ''
        ${
          lib.escapeShellArgs [
            (lib.getExe launchLlamaServer)
            "${model.repoCacheDirectory}/snapshots"
            (if model.revision == null then "*" else model.revision)
            model.primaryPath
            llamaServer
          ]
        } ''${PORT} ${lib.escapeShellArgs modelArgs}
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
    environment.systemPackages = [
      llamaPackage
      pkgs.llama-swap
    ];

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
