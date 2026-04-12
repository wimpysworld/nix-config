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

  # Package selection based on acceleration framework.
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

  # Vulkan build with prefixed binaries for cross-backend benchmarking.
  llamaCppVulkan = pkgs.symlinkJoin {
    name = "llama-cpp-vulkan-prefixed";
    paths = [
      (pkgs.llama-cpp.override {
        vulkanSupport = true;
        rocmSupport = false;
        cudaSupport = false;
      })
    ];
    postBuild = ''
      for f in "$out/bin/"*; do
        mv "$f" "$(dirname "$f")/vulkan-$(basename "$f")"
      done
    '';
  };

  # Only include the Vulkan comparison build when the primary backend is not already Vulkan.
  extraPackages = lib.optionals (accel != "vulkan") [ llamaCppVulkan ];
in
lib.mkIf isInference {
  environment.systemPackages = [ llamaPackage ] ++ extraPackages;
}
