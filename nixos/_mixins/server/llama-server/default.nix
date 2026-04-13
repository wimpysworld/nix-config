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
  hostVramGiB = host.gpu.compute.vram or 0;

  modelPolicy = import ./model-policy.nix { inherit lib; };
  selectedPolicy = modelPolicy.mkSelection { inherit hostVramGiB; };
  inherit (selectedPolicy)
    modelMatrix
    selectedModelTier
    selectedModels
    ;

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
in
{
  imports = [
    ./preseed.nix
  ];

  config = lib.mkIf isInference {
    environment.systemPackages = [ llamaPackage ];
  };
}
