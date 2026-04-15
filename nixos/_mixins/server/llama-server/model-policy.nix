{ lib }:
let
  mkModel =
    {
      modelRef,
      maxContext,
      generation ? null,
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
        modelRef
        ;
      llamaServerArgs = [
        "--ctx-size"
        (toString maxContext)
        "--cache-type-k"
        kvCache.k
        "--cache-type-v"
        kvCache.v
      ]
      ++ generationArgs;
    };

  modelMatrix = {
    vram64 = {
      minVramGiB = 64;
      name = "vram64";
      models = {
        coding = mkModel {
          modelRef = "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 40;
            repetitionPenalty = 1.0;
            minP = 0.01;
          };
        };
        agentic = mkModel {
          modelRef = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 20;
            repetitionPenalty = 1.0;
            minP = 0.0;
            presencePenalty = 1.5;
          };
        };
        reasoning = mkModel {
          modelRef = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        smallMedia = mkModel {
          modelRef = "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL";
          maxContext = 131072;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        embedding = mkModel {
          modelRef = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
          maxContext = 40960;
        };
      };
    };

    vram32 = {
      minVramGiB = 32;
      name = "vram32";
      models = {
        coding = mkModel {
          modelRef = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 0.7;
            topP = 0.8;
            topK = 20;
            repetitionPenalty = 1.05;
            minP = 0.0;
          };
        };
        agentic = mkModel {
          modelRef = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 20;
            repetitionPenalty = 1.0;
            minP = 0.0;
            presencePenalty = 1.5;
          };
        };
        reasoning = mkModel {
          modelRef = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        smallMedia = mkModel {
          modelRef = "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL";
          maxContext = 131072;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        embedding = mkModel {
          modelRef = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
          maxContext = 40960;
        };
      };
    };

    vram22 = {
      minVramGiB = 22;
      name = "vram22";
      models = {
        coding = mkModel {
          modelRef = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 0.7;
            topP = 0.8;
            topK = 20;
            repetitionPenalty = 1.05;
            minP = 0.0;
          };
        };
        agentic = mkModel {
          modelRef = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 20;
            repetitionPenalty = 1.0;
            minP = 0.0;
            presencePenalty = 1.5;
          };
        };
        reasoning = mkModel {
          modelRef = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        smallMedia = mkModel {
          modelRef = "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL";
          maxContext = 131072;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        embedding = mkModel {
          modelRef = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
          maxContext = 40960;
        };
      };
    };

    vram16 = {
      minVramGiB = 16;
      name = "vram16";
      models = {
        coding = mkModel {
          modelRef = "unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF:Q4_K_M";
          maxContext = 131072;
        };
        agentic = mkModel {
          modelRef = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 20;
            repetitionPenalty = 1.0;
            minP = 0.0;
            presencePenalty = 1.5;
          };
        };
        reasoning = mkModel {
          modelRef = "unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL";
          maxContext = 131072;
          generation = {
            temperature = 1.0;
            topP = 1.0;
            topK = 0;
            repetitionPenalty = 1.0;
          };
        };
        smallMedia = mkModel {
          modelRef = "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL";
          maxContext = 131072;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 64;
            repetitionPenalty = 1.0;
          };
        };
        embedding = mkModel {
          modelRef = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
          maxContext = 40960;
        };
      };
    };

    vram8 = {
      minVramGiB = 8;
      name = "vram8";
      models = {
        coding = mkModel {
          modelRef = "unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF:Q4_K_M";
          maxContext = 131072;
        };
        agentic = mkModel {
          modelRef = "unsloth/rnj-1-instruct-GGUF:UD-Q4_K_XL";
          maxContext = 32768;
        };
        reasoning = mkModel {
          modelRef = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
          maxContext = 262144;
          generation = {
            temperature = 1.0;
            topP = 0.95;
            topK = 20;
            repetitionPenalty = 1.0;
            minP = 0.0;
            presencePenalty = 1.5;
          };
        };
        smallMedia = mkModel {
          modelRef = "unsloth/gemma-4-E2B-it-GGUF:UD-Q6_K_XL";
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
          maxContext = 32768;
        };
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
