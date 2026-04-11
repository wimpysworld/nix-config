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
  inherit (host.gpu.compute) vram;
  accel = host.gpu.compute.acceleration;

  # Package selection based on acceleration framework.
  # services.ollama.acceleration was removed from nixpkgs; use package variants.
  ollamaPackage =
    if accel == "cuda" then
      pkgs.ollama-cuda
    else if accel == "rocm" then
      pkgs.ollama-rocm
    else if accel == "vulkan" then
      pkgs.ollama-vulkan
    else
      pkgs.ollama;

  # VRAM-based model tier selection.
  codingModel =
    if vram >= 17 then
      "qwen3.5:27b"
    else if vram >= 7 then
      "qwen3.5:9b"
    else
      "qwen3.5:4b";
  generalModel =
    if vram >= 24 then
      "qwen3.5:35b-a3b"
    else if vram >= 17 then
      "qwen3.5:27b"
    else if vram >= 7 then
      "qwen3.5:9b"
    else
      "qwen3.5:4b";
  embeddingModel =
    if vram >= 5 then
      "qwen3-embedding:4b-q8_0"
    else if vram > 3 then
      "qwen3-embedding:4b"
    else
      "qwen3-embedding:0.6b";
  mediaModel =
    if vram >= 5 then
      "gemma4:e4b"
    else if vram >= 3 then
      "gemma4:e2b"
    else
      null;

  allModels = lib.filter (m: m != null) [
    codingModel
    embeddingModel
    generalModel
    mediaModel
  ];
in
lib.mkIf isInference {
  environment = {
    shellAliases.ollama-log = "journalctl _SYSTEMD_UNIT=ollama.service";
    systemPackages = [ pkgs.oterm ];
  };
  services.ollama = {
    enable = true;
    package = ollamaPackage;
    host = if host.is.server then "0.0.0.0" else "127.0.0.1";
    loadModels = allModels;
  };
}
