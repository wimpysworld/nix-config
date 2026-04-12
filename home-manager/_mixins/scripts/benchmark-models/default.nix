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
  accel = host.gpu.compute.acceleration;
  isInference = builtins.elem "inference" host.tags;

  mkPrefixedLlamaCpp =
    prefix: package:
    pkgs.symlinkJoin {
      name = "llama-cpp-${prefix}-prefixed";
      paths = [ package ];
      postBuild = ''
        for f in "$out/bin/"*; do
          mv "$f" "$(dirname "$f")/${prefix}-$(basename "$f")"
        done
      '';
    };

  cudaLlamaCpp = mkPrefixedLlamaCpp "cuda" (
    pkgs.llama-cpp.override {
      cudaSupport = true;
      rocmSupport = false;
      vulkanSupport = false;
    }
  );

  rocmLlamaCpp = mkPrefixedLlamaCpp "rocm" (
    pkgs.llama-cpp.override {
      rocmSupport = true;
      cudaSupport = false;
      vulkanSupport = false;
    }
  );

  vulkanLlamaCpp = mkPrefixedLlamaCpp "vulkan" (
    pkgs.llama-cpp.override {
      vulkanSupport = true;
      rocmSupport = false;
      cudaSupport = false;
    }
  );

  ollamaPackage =
    if accel == "cuda" then
      pkgs.ollama-cuda
    else if accel == "rocm" then
      pkgs.ollama-rocm
    else if accel == "vulkan" then
      pkgs.ollama-vulkan
    else
      pkgs.ollama;

  backendPackages =
    if vendor == "nvidia" then
      [
        cudaLlamaCpp
        vulkanLlamaCpp
      ]
    else if vendor == "amd" then
      [
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
        hyperfine
        jq
        python3Packages.huggingface-hub
        ollamaPackage
      ]
      ++ backendPackages;
    text = benchmarkEnv + builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (host.is.linux && isInference) {
  home.packages = [ shellApplication ];
}
