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

  modelDownloads = import ../../../../nixos/_mixins/server/llama-server/model-downloads.nix;
  inherit (import ../../../../nixos/_mixins/server/llama-server/runtime.nix { inherit lib; })
    defaultCacheRoot
    ;
  modelSnapshot =
    model:
    let
      repo = lib.replaceStrings [ "/" ] [ "--" ] model.hfRepo;
    in
    "hub/models--${repo}/snapshots/${model.revision}/${model.primaryPath}";

  mkPrefixedBackend =
    prefix: package:
    pkgs.symlinkJoin {
      name = "${package.name}-${prefix}-prefixed";
      paths = [ package ];
      postBuild = ''
        for f in "$out/bin/"*; do
          mv "$f" "$(dirname "$f")/${prefix}-$(basename "$f")"
        done
      '';
    };

  cudaLlamaCpp = mkPrefixedBackend "cuda" (
    pkgs.llama-cpp.override {
      cudaSupport = true;
      rocmSupport = false;
      vulkanSupport = false;
    }
  );

  rocmLlamaCpp = mkPrefixedBackend "rocm" (
    pkgs.llama-cpp.override {
      rocmSupport = true;
      cudaSupport = false;
      vulkanSupport = false;
    }
  );

  vulkanLlamaCpp = mkPrefixedBackend "vulkan" (
    pkgs.llama-cpp.override {
      vulkanSupport = true;
      rocmSupport = false;
      cudaSupport = false;
    }
  );

  cudaOllama = mkPrefixedBackend "cuda" pkgs.ollama-cuda;
  rocmOllama = mkPrefixedBackend "rocm" pkgs.ollama-rocm;
  vulkanOllama = mkPrefixedBackend "vulkan" pkgs.ollama-vulkan;

  focusedRocm = pkgs.llama-cpp-inkling.override {
    rocmSupport = true;
    rocmGpuTargets = [ "gfx1151" ];
    cudaSupport = false;
    vulkanSupport = false;
  };

  focusedVulkan = pkgs.llama-cpp-inkling.override {
    vulkanSupport = true;
    rocmSupport = false;
    cudaSupport = false;
  };

  backendPackages =
    if vendor == "nvidia" then
      [
        cudaOllama
        vulkanOllama
        cudaLlamaCpp
        vulkanLlamaCpp
      ]
    else if vendor == "amd" then
      [
        rocmOllama
        vulkanOllama
        rocmLlamaCpp
        vulkanLlamaCpp
      ]
    else
      [ ];

  benchmarkEnv = ''
    BENCHMARK_MODELS_HOST_GPU_COMPUTE_VENDOR="${if vendor != null then vendor else ""}"
    BENCHMARK_FOCUSED_SCRIPT=${./focused.py}
  ''
  + lib.optionalString (isStrixHalo && vendor == "amd") ''
    export BENCHMARK_MODELS_VULKAN_SERVER="''${BENCHMARK_MODELS_VULKAN_SERVER:-${focusedVulkan}/bin/llama-server}"
    export BENCHMARK_MODELS_ROCM_SERVER="''${BENCHMARK_MODELS_ROCM_SERVER:-${focusedRocm}/bin/llama-server}"
    export BENCHMARK_FOCUSED_CACHE=${lib.escapeShellArg defaultCacheRoot}
    export BENCHMARK_FOCUSED_INKLING_SNAPSHOT=${
      lib.escapeShellArg (modelSnapshot modelDownloads."unsloth/Inkling-2-Mini-GGUF:UD-Q4_K_XL")
    }
    export BENCHMARK_FOCUSED_QWEN_SNAPSHOT=${
      lib.escapeShellArg (modelSnapshot modelDownloads."unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL")
    }
  '';

  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs =
      with pkgs;
      [
        coreutils
        curl
        gawk
        jq
        python3
        python3Packages.huggingface-hub
      ]
      ++ backendPackages;
    text = benchmarkEnv + builtins.readFile ./${name}.sh;
  };

  shellApplicationAll = pkgs.writeShellApplication {
    name = "${name}-all";
    runtimeInputs = [ shellApplication ];
    text = builtins.readFile ./benchmark-models-all.sh;
  };
in
lib.mkIf (host.is.linux && isInference) {
  home.packages = [
    shellApplication
    shellApplicationAll
  ];
}
