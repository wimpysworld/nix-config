{ lib }:
let
  mkModel =
    {
      modelRef,
      maxContext,
      generation ? null,
      reasoning ? null,
      reasoningEffort ? null,
      singleSlot ? false,
      microBatchSize ? null,
      mtpDraftTokens ? null,
    }:
    let
      kvCache = {
        k = "q8_0";
        v = "q8_0";
      };
      generationArgs =
        if generation == null then
          [ ]
        else
          [
            "--temp"
            (toString generation.temperature)
            "--top-p"
            (toString generation.topP)
            "--top-k"
            (toString generation.topK)
            "--repeat-penalty"
            (toString generation.repetitionPenalty)
          ]
          ++ lib.optionals (generation ? minP) [
            "--min-p"
            (toString generation.minP)
          ]
          ++ lib.optionals (generation ? presencePenalty) [
            "--presence-penalty"
            (toString generation.presencePenalty)
          ];
    in
    {
      inherit
        generation
        kvCache
        maxContext
        microBatchSize
        modelRef
        mtpDraftTokens
        reasoning
        reasoningEffort
        singleSlot
        ;
      llamaServerArgs = [
        "--ctx-size"
        (toString maxContext)
        "--cache-type-k"
        kvCache.k
        "--cache-type-v"
        kvCache.v
      ]
      ++ generationArgs
      ++ lib.optionals (reasoning != null) [
        "--reasoning"
        reasoning
      ]
      ++ lib.optionals (reasoningEffort != null) [
        "--reasoning-effort"
        reasoningEffort
      ]
      ++ lib.optionals singleSlot [
        "--parallel"
        "1"
        "--no-context-shift"
      ]
      ++ lib.optionals (microBatchSize != null) [
        "--ubatch-size"
        (toString microBatchSize)
      ];
    };

  mkInkling =
    {
      maxContext,
    }:
    mkModel {
      inherit maxContext;
      modelRef = "unsloth/Inkling-2-Mini-GGUF:UD-Q4_K_XL";
      microBatchSize = 128;
      singleSlot = true;
      # Use the sampling settings from Unsloth's Inkling 2 Mini guide.
      generation = {
        temperature = 1.0;
        topP = 1.0;
        topK = 0;
        minP = 0.0;
        repetitionPenalty = 1.0;
      };
    };

  mkMellum =
    {
      quant,
    }:
    mkModel {
      maxContext = 131072;
      modelRef = "JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF:${quant}";
      singleSlot = true;
      # Use the sampling settings from JetBrains's Mellum2.1 GGUF README.
      generation = {
        temperature = 0.6;
        topP = 0.95;
        topK = 20;
        minP = 0.0;
        repetitionPenalty = 1.0;
      };
    };

  mkQwen =
    {
      maxContext,
    }:
    mkModel {
      inherit maxContext;
      modelRef = "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL";
      mtpDraftTokens = 3;
      reasoningEffort = "medium";
      singleSlot = true;
      # Use the thinking-mode sampling settings from Unsloth's Qwen3.8 guide.
      generation = {
        temperature = 1.0;
        topP = 0.95;
        topK = 20;
        minP = 0.0;
        presencePenalty = 0.0;
        repetitionPenalty = 1.0;
      };
    };

  mkQwen35 =
    {
      maxContext,
    }:
    mkModel {
      inherit maxContext;
      modelRef = "unsloth/Qwen3.5-9B-MTP-GGUF:UD-Q4_K_XL";
      reasoning = "off";
      # Use the non-thinking general instruct settings from Unsloth's Qwen3.5 guide.
      generation = {
        temperature = 0.7;
        topP = 0.8;
        topK = 20;
        minP = 0.0;
        presencePenalty = 1.5;
        repetitionPenalty = 1.0;
      };
    };

  embedding = mkModel {
    modelRef = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
    maxContext = 8192;
  };

  standardModels = {
    inherit embedding;
  };

  modelMatrix = {
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = standardModels // {
        moe = mkInkling { maxContext = 262144; };
        dense = mkQwen { maxContext = 262144; };
      };
    };

    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = standardModels // {
        moe = mkInkling { maxContext = 262144; };
        dense = mkQwen { maxContext = 262144; };
      };
    };

    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = standardModels // {
        moe = mkMellum { quant = "Q8_0"; };
        dense = mkQwen35 { maxContext = 262144; };
      };
    };

    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = standardModels // {
        moe = mkMellum { quant = "Q6_K"; };
        dense = mkQwen35 { maxContext = 131072; };
      };
    };
  };

  modelTiers = [
    modelMatrix.vram64
    modelMatrix.vram32
    modelMatrix.vram22
    modelMatrix.vram16
  ];

  fallbackTier = modelMatrix.vram16;
in
{
  inherit modelMatrix modelTiers;

  selectedModelReferences = lib.unique (
    lib.concatMap (tier: map (model: model.modelRef) (builtins.attrValues tier.models)) modelTiers
  );

  mkSelection =
    {
      hostVramGiB ? 0,
    }:
    let
      selectedModelTier = lib.findFirst (tier: hostVramGiB >= tier.minVramGiB) fallbackTier modelTiers;
    in
    {
      inherit modelMatrix modelTiers selectedModelTier;
      selectedModels = selectedModelTier.models;
    };
}
