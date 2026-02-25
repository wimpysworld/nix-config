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
  defaultModel =
    if vram >= 65 then
      "gpt-oss:120b"
    else if vram >= 14 then
      "gpt-oss:20b"
    else
      "rnj-1:8b";
  generalModel =
    if vram >= 20 then
      "qwen3:30b"
    else if vram >= 10 then
      "qwen3:14b"
    else
      "qwen3:8b";
  codingModel =
    if vram >= 20 then
      "qwen3-coder:30b"
    else if vram >= 10 then
      "qwen2.5-coder:14b"
    else
      "qwen2.5-coder:7b";
  embeddingModel =
    if vram >= 5 then
      "qwen3-embedding:8b"
    else if vram > 3 then
      "qwen3-embedding:4b"
    else
      "qwen3-embedding:0.6b";
  visionModel =
    if vram >= 21 then
      "qwen3-vl:32b"
    else if vram >= 7 then
      "qwen3-vl:8b"
    else
      "qwen3-vl:4b";
  taskModel = "rnj-1:8b";

  allModels = [
    codingModel
    defaultModel
    embeddingModel
    generalModel
    taskModel
    visionModel
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
