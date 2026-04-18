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
  runtime = import ./runtime.nix { inherit lib; };
  cacheRoot = runtime.defaultCacheRoot;
  selectedRuntime = runtime.mkRuntime {
    acceleration = host.gpu.compute.acceleration or null;
    inherit cacheRoot;
    hostVramGiB = host.gpu.compute.vram or 0;
  };

  preseedModelsJson = pkgs.writeText "llama-models-preseed.json" (
    builtins.toJSON selectedRuntime.selectedModelDownloads
  );
  preseedModels = pkgs.writeShellApplication {
    name = "llama-preseed-models";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      jq
      python3Packages.huggingface-hub
    ];
    text = builtins.readFile ./preseed-models.sh;
  };
in
{
  config = lib.mkIf isInference {
    assertions = [
      {
        assertion = selectedRuntime.selectedModels != { };
        message = "llama-server preseed requires a non-empty selected model set.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cacheRoot} 0755 root root -"
      "d ${cacheRoot}/hub 0755 root root -"
      "d ${cacheRoot}/tmp 0755 root root -"
      "d ${cacheRoot}/transformers 0755 root root -"
      "d ${cacheRoot}/xdg/cache 0755 root root -"
      "d ${cacheRoot}/xdg/config 0755 root root -"
      "d ${cacheRoot}/xdg/data 0755 root root -"
    ];

    systemd.services.llama-models-preseed = {
      description = "Pre-seed llama.cpp Hugging Face models";
      requiredBy = [ "llama-swap.service" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      before = [ "llama-swap.service" ];
      environment = {
        HF_HOME = cacheRoot;
        HF_HUB_CACHE = "${cacheRoot}/hub";
        HUGGINGFACE_HUB_CACHE = "${cacheRoot}/hub";
        LLAMA_PRESEED_CACHE_ROOT = cacheRoot;
        LLAMA_PRESEED_MODELS_JSON = "${preseedModelsJson}";
        TMPDIR = "${cacheRoot}/tmp";
        TRANSFORMERS_CACHE = "${cacheRoot}/transformers";
        XDG_CACHE_HOME = "${cacheRoot}/xdg/cache";
        XDG_CONFIG_HOME = "${cacheRoot}/xdg/config";
        XDG_DATA_HOME = "${cacheRoot}/xdg/data";
      };
      path = with pkgs; [
        coreutils
        findutils
        jq
        python3Packages.huggingface-hub
      ];
      serviceConfig = {
        Type = "exec";
        User = "root";
        ExecStart = lib.getExe preseedModels;
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
