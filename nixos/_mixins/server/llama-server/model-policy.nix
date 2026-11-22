{ lib }:
let
  mkModel =
    {
      modelRef,
      maxContext,
      generation ? null,
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
      quant ? "UD-Q4_K_XL",
      maxContext,
      microBatchSize ? null,
    }:
    mkModel {
      inherit maxContext microBatchSize;
      modelRef = "unsloth/Inkling-2-Mini-GGUF:${quant}";
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

  mkQwen =
    {
      quant ? "UD-Q4_K_XL",
      maxContext,
      mtpDraftTokens ? null,
    }:
    mkModel {
      inherit maxContext mtpDraftTokens;
      modelRef = "unsloth/Qwen3.8-27B-GGUF:${quant}";
      reasoningEffort = "medium";
      singleSlot = true;
      # Use the model card's thinking-mode sampling settings.
      generation = {
        temperature = 1.0;
        topP = 0.95;
        topK = 20;
        minP = 0.0;
        presencePenalty = 0.0;
        repetitionPenalty = 1.0;
      };
    };

  mkSmallMedia =
    size:
    mkModel {
      modelRef = "unsloth/gemma-4-E${size}B-it-GGUF:UD-Q6_K_XL";
      maxContext = 131072;
      generation = {
        temperature = 1.0;
        topP = 0.95;
        topK = 64;
        repetitionPenalty = 1.0;
      };
    };

  embedding = mkModel {
    modelRef = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
    maxContext = 8192;
  };

  standardModels = {
    inherit embedding;
    smallMedia = mkSmallMedia "4";
  };

  modelMatrix = {
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = standardModels // {
        moe = mkInkling {
          maxContext = 262144;
          microBatchSize = 128;
        };
        dense = mkQwen {
          maxContext = 262144;
          mtpDraftTokens = 2;
        };
      };
    };

    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = standardModels // {
        moe = mkInkling { maxContext = 32768; };
        dense = mkQwen { maxContext = 65536; };
      };
    };

    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = standardModels // {
        moe = mkInkling { maxContext = 16384; };
        dense = mkQwen { maxContext = 32768; };
      };
    };

    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = standardModels // {
        moe = mkInkling {
          quant = "UD-IQ3_XXS";
          maxContext = 16384;
        };
        dense = mkQwen {
          quant = "UD-Q3_K_XL";
          maxContext = 16384;
        };
      };
    };

    vram8 = {
      minVramGiB = 8;
      name = "vram8";
      models = {
        inherit embedding;
        smallMedia = mkSmallMedia "2";
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
