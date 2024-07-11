{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "sidious"
    "tanis"
    "vader"
  ];
  hasCUDA = lib.elem "cudaPackages.cudatoolkit" config.environment.systemPackages;
  hasOpenCL = config.hardware.amdgpu.opencl.enable;
in
lib.mkIf (lib.elem hostname installOn) {
  environment.systemPackages = with pkgs; [
    (blender.override {
      cudaSupport = hasCUDA;
      hipSupport = hasOpenCL;
    })
  ];
}
