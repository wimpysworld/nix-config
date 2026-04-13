{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isInference = noughtyLib.hostHasTag "inference";

  modelPolicy = import ./model-policy.nix { inherit lib; };
  selectedPolicy = modelPolicy.mkSelection {
    hostVramGiB = host.gpu.compute.vram or 0;
  };
in
{
  config = lib.mkIf isInference {
    assertions = [
      {
        assertion = selectedPolicy.selectedModels != { };
        message = "llama-server preseed requires a non-empty selected model set.";
      }
    ];
  };
}
