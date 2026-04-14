{ lib }:
let
  mkModel =
    modelRef: maxContext:
    let
      kvCache = {
        k = "q8_0";
        v = "q8_0";
      };
    in
    {
      inherit kvCache maxContext modelRef;
      llamaServerArgs = [
        "--ctx-size"
        (toString maxContext)
        "--cache-type-k"
        kvCache.k
        "--cache-type-v"
        kvCache.v
      ];
    };

  modelMatrix = {
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = {
        coding = mkModel "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL" 262144;
        agentic = mkModel "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL" 262144;
        reasoning = mkModel "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL" 262144;
        smallMedia = mkModel "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL" 131072;
        embedding = mkModel "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" 40960;
      };
    };

    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = {
        coding = mkModel "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL" 262144;
        agentic = mkModel "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL" 262144;
        reasoning = mkModel "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL" 262144;
        smallMedia = mkModel "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL" 131072;
        embedding = mkModel "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" 40960;
      };
    };

    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = {
        coding = mkModel "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL" 262144;
        agentic = mkModel "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL" 262144;
        reasoning = mkModel "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL" 262144;
        smallMedia = mkModel "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL" 131072;
        embedding = mkModel "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" 40960;
      };
    };

    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = {
        coding = mkModel "unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF:Q4_K_M" 131072;
        agentic = mkModel "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL" 262144;
        reasoning = mkModel "unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL" 131072;
        smallMedia = mkModel "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL" 131072;
        embedding = mkModel "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" 40960;
      };
    };

    vram8 = {
      minVramGiB = 8;
      name = "vram8";
      models = {
        coding = mkModel "unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF:Q4_K_M" 131072;
        agentic = mkModel "EssentialAI/rnj-1-instruct-GGUF:Q4_K_M" 32768;
        reasoning = mkModel "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL" 262144;
        smallMedia = mkModel "unsloth/gemma-4-E2B-it-GGUF:UD-Q6_K_XL" 131072;
        embedding = mkModel "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0" 32768;
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
    lib.concatMap (tier: map (model: model.modelRef) (builtins.attrValues tier.models)) modelTiers
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
