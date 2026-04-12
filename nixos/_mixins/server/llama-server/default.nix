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

  modelMatrix = {
    # Full local stack for big unified-memory inference hosts.
    # High-memory embedding tiers pin the 4B model to q8_0.
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = {
        coding = "unsloth/Qwen3-Coder-Next-GGUF";
        general = "unsloth/Qwen3.5-35B-A3B-GGUF";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF";
        embedding = "Qwen/Qwen3-Embedding-4B-GGUF:q8_0";
      };
    };

    # 32 GB keeps the strong Qwen MoE for coding and Gemma4 MoE in the general slot.
    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = {
        coding = "unsloth/Qwen3.5-35B-A3B-GGUF";
        general = "unsloth/gemma-4-26B-A4B-it-GGUF";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF";
        embedding = "Qwen/Qwen3-Embedding-4B-GGUF:q8_0";
      };
    };

    # 22 GB moves to the smaller Gemma MoE-style fallback tier.
    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = {
        coding = "unsloth/gemma-4-26B-A4B-it-GGUF";
        general = "unsloth/gemma-4-26B-A4B-it-GGUF";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF";
        embedding = "Qwen/Qwen3-Embedding-4B-GGUF";
      };
    };

    # 16 GB keeps a single small MoE-capable model for the main slots.
    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = {
        coding = "unsloth/Qwen3.5-9B-GGUF";
        general = "unsloth/Qwen3.5-9B-GGUF";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF";
        embedding = "Qwen/Qwen3-Embedding-0.6B-GGUF";
      };
    };

    # 8 GB stays on the same small general MoE tier.
    vram8 = {
      minVramGiB = 8;
      name = "vram8";
      models = {
        coding = "unsloth/Qwen3.5-9B-GGUF";
        general = "unsloth/Qwen3.5-9B-GGUF";
        smallMedia = "unsloth/gemma-4-E2B-it-GGUF";
        embedding = "Qwen/Qwen3-Embedding-0.6B-GGUF";
      };
    };
  };

  modelTiers = [
    modelMatrix.vram64
    modelMatrix.vram32
    modelMatrix.vram22
    modelMatrix.vram16
    modelMatrix.vram8
  ];

  selectedModelTier = lib.findFirst (
    tier: hostVramGiB >= tier.minVramGiB
  ) modelMatrix.vram4 modelTiers;

  # Derived now so follow-up work can consume a ready host-specific model set.
  selectedModels = selectedModelTier.models;

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
