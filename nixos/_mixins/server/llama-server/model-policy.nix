{ lib }:
let
  modelMatrix = {
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = {
        coding = "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
        general = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
        embedding = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
      };
    };

    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = {
        coding = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
        general = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
        embedding = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
      };
    };

    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = {
        coding = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
        general = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
        embedding = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
      };
    };

    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = {
        coding = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
        general = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
        smallMedia = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
        embedding = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
      };
    };

    vram8 = {
      minVramGiB = 8;
      name = "vram8";
      models = {
        coding = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
        general = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
        smallMedia = "unsloth/gemma-4-E2B-it-GGUF:UD-Q4_K_XL";
        embedding = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
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

  fallbackTier = modelMatrix.vram8;
in
{
  inherit modelMatrix modelTiers;

  selectedModelReferences = lib.unique (
    lib.concatMap (tier: builtins.attrValues tier.models) modelTiers
  );

  mkSelection =
    { hostVramGiB ? 0 }:
    let
      selectedModelTier = lib.findFirst (tier: hostVramGiB >= tier.minVramGiB) fallbackTier modelTiers;
    in
    {
      inherit modelMatrix modelTiers selectedModelTier;
      selectedModels = selectedModelTier.models;
    };
}
