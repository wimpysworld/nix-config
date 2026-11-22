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

  runtime = import ./runtime.nix { inherit lib; };
  llamaPackage = runtime.packageForAcceleration accel pkgs.llama-cpp;
in
{
  imports = [
    ./swap.nix
    ./preseed.nix
  ];

  config = lib.mkIf isInference {
    environment.systemPackages = [
      llamaPackage
      pkgs.llama-swap
    ];
  };
}
