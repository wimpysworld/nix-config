{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  inherit (host.gpu.compute) vendor;
  isInference = builtins.elem "inference" host.tags;
  isStrixHalo = builtins.elem "strix-halo" host.tags;

  inherit (import ../../../../nixos/_mixins/server/llama-server/runtime.nix { inherit lib; })
    defaultCacheRoot
    mkRuntime
    ;
  inherit (mkRuntime { hostVramGiB = host.gpu.compute.vram or 0; })
    selectedRuntimeModels
    ;
  qwenSmall = (mkRuntime { hostVramGiB = 16; }).selectedRuntimeModels.dense;
  tierModels = map (role: selectedRuntimeModels.${role}) (
    lib.filter (role: selectedRuntimeModels ? ${role}) [
      "moe"
      "dense"
    ]
  );
  hasQwenSmall = lib.any (model: model.publicName == qwenSmall.publicName) tierModels;
  suiteModels = tierModels ++ lib.optional (!hasQwenSmall) qwenSmall;
  models = builtins.listToAttrs (map (model: lib.nameValuePair model.publicName model) suiteModels);
  profiles = lib.mapAttrs (
    _: model:
    let
      inherit (model) generation;
    in
    {
      inherit (model)
        microBatchSize
        mtpDraftTokens
        reasoning
        reasoningEffort
        ;
      supportsMtp = model.supportsMtp or false;
      sampling = lib.filterAttrs (_: value: value != null) {
        inherit (generation) temperature;
        top_k = generation.topK;
        top_p = generation.topP;
        min_p = generation.minP or null;
        repeat_penalty = generation.repetitionPenalty;
        presence_penalty = generation.presencePenalty or null;
      };
    }
    // lib.optionalAttrs (model ? resolvedPrimaryPathPattern) {
      snapshot = lib.removePrefix "${defaultCacheRoot}/" model.resolvedPrimaryPathPattern;
      inherit (model.download)
        downloadPaths
        hfRepo
        primaryPath
        projectorPath
        revision
        ;
    }
  ) models;

  backends =
    if vendor == "nvidia" then
      [
        "vulkan"
        "cuda"
      ]
    else if vendor == "amd" then
      [
        "vulkan"
        "rocm"
      ]
    else if host.gpu.compute.acceleration == "vulkan" then
      [ "vulkan" ]
    else
      [ ];

  backendEnv = lib.concatMapStrings (
    backend:
    let
      llamaCpp = pkgs.llama-cpp.override (
        {
          cudaSupport = backend == "cuda";
          rocmSupport = backend == "rocm";
          vulkanSupport = backend == "vulkan";
        }
        // lib.optionalAttrs (backend == "rocm" && isStrixHalo) {
          rocmGpuTargets = [ "gfx1151" ];
        }
      );
      ollama = pkgs."ollama-${backend}";
      prefix = "BENCHMARK_MODELS_${lib.toUpper backend}";
    in
    ''
      export ${prefix}_SERVER=${lib.escapeShellArg "${llamaCpp}/bin/llama-server"}
      export ${prefix}_OLLAMA=${lib.escapeShellArg "${ollama}/bin/ollama"}
    ''
  ) backends;

  benchmarkEnv = ''
    BENCHMARK_COMPARISON_SCRIPT=${./focused.py}
    export BENCHMARK_MODELS_BACKENDS=${lib.escapeShellArg (lib.concatStringsSep " " backends)}
    export BENCHMARK_MODELS_PRESEED_CACHE=${lib.escapeShellArg defaultCacheRoot}
    export BENCHMARK_MODELS_PROFILES=${lib.escapeShellArg (builtins.toJSON profiles)}
  ''
  + backendEnv;

  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      jq
      python3
      huggingface-cli
    ];
    text = benchmarkEnv + builtins.readFile ./${name}.sh;
    derivationArgs.postCheck = ''
      ${pkgs.python3}/bin/python3 ${./test-focused.py} ${./focused.py}
    '';
  };

  shellApplicationAll = pkgs.writeShellApplication {
    name = "${name}-all";
    runtimeInputs = with pkgs; [
      huggingface-cli
      python3
    ];
    text =
      benchmarkEnv
      + ''
        suiteModels=(${lib.escapeShellArgs (map (model: model.publicName) suiteModels)})
      ''
      + builtins.readFile ./benchmark-models-all.sh;
  };
in
lib.mkIf (host.is.linux && isInference) {
  home.packages = [
    shellApplication
    shellApplicationAll
  ];
}
