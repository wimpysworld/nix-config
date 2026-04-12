{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  vendor = host.gpu.compute.vendor;
  isInference = builtins.elem "inference" host.tags;

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
        python3Packages.huggingface-hub
      ]
      ++ backendPackages;
    text = benchmarkEnv + builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (host.is.linux && isInference) {
  home.packages = [ shellApplication ];
}
