let
  singleFile =
    {
      hfRepo,
      path,
      publicName,
      revision ? null,
      backend ? "llama-cpp",
    }:
    {
      inherit
        backend
        hfRepo
        publicName
        revision
        ;
      primaryPath = path;
      downloadPaths = [ path ];
    };

  inkling =
    quant:
    singleFile {
      hfRepo = "unsloth/Inkling-2-Mini-GGUF";
      path = "Mainline_Support/Inkling-2-Mini-${quant}.gguf_file";
      publicName = "inkling-2-mini";
      revision = "45fd08764f2b0bf16b03a5483a80e5c7aaec8772";
      backend = "llama-cpp-inkling";
    };

  qwen =
    quant:
    singleFile {
      hfRepo = "unsloth/Qwen3.8-27B-GGUF";
      path = "Qwen3.8-27B-${quant}.gguf";
      publicName = "qwen3.8-27b";
      revision = "4af51b3542f775b0a8e4b310bfb3f17e01c306c9";
      backend = "llama-cpp-inkling";
    };
in
{
  "unsloth/Inkling-2-Mini-GGUF:UD-Q4_K_XL" = inkling "UD-Q4_K_XL";
  "unsloth/Inkling-2-Mini-GGUF:UD-IQ3_XXS" = inkling "UD-IQ3_XXS";
  "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL" = qwen "UD-Q4_K_XL";
  "unsloth/Qwen3.8-27B-GGUF:UD-Q3_K_XL" = qwen "UD-Q3_K_XL";

  "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0" = singleFile {
    hfRepo = "Qwen/Qwen3-Embedding-0.6B-GGUF";
    path = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    publicName = "qwen3-embedding-0.6b";
  };
  "unsloth/gemma-4-E2B-it-GGUF:UD-Q6_K_XL" = singleFile {
    hfRepo = "unsloth/gemma-4-E2B-it-GGUF";
    path = "gemma-4-E2B-it-UD-Q6_K_XL.gguf";
    publicName = "gemma4-e2b";
  };
  "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL" = singleFile {
    hfRepo = "unsloth/gemma-4-E4B-it-GGUF";
    path = "gemma-4-E4B-it-UD-Q6_K_XL.gguf";
    publicName = "gemma4-e4b";
  };
}
