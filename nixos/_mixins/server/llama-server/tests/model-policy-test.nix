{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  selection = modelPolicy.mkSelection { hostVramGiB = 96; };
  vram32Selection = modelPolicy.mkSelection { hostVramGiB = 32; };
  vram16Selection = modelPolicy.mkSelection { hostVramGiB = 16; };
  vram8Selection = modelPolicy.mkSelection { hostVramGiB = 8; };
in
assert selection.selectedModelTier.name == "vram64";
assert selection.selectedModels.coding.modelRef == "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.agentic.modelRef == "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.reasoning.modelRef == "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.embedding.modelRef == "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
assert selection.selectedModels.agentic.maxContext == 262144;
assert selection.selectedModels.embedding.maxContext == 40960;
assert selection.selectedModels.embedding.kvCache.k == "q8_0";
assert selection.selectedModels.embedding.kvCache.v == "q8_0";
assert selection.selectedModels.coding.generation.temperature == 1.0;
assert selection.selectedModels.coding.generation.topP == 0.95;
assert selection.selectedModels.coding.generation.topK == 40;
assert selection.selectedModels.coding.generation.repetitionPenalty == 1.0;
assert selection.selectedModels.coding.generation.minP == 0.01;
assert selection.selectedModels.agentic.generation.presencePenalty == 1.5;
assert
  selection.selectedModels.agentic.llamaServerArgs == [
    "--ctx-size"
    "262144"
    "--cache-type-k"
    "q8_0"
    "--cache-type-v"
    "q8_0"
    "--temp"
    "1.000000"
    "--top-p"
    "0.950000"
    "--top-k"
    "20"
    "--repeat-penalty"
    "1.000000"
    "--min-p"
    "0.000000"
    "--presence-penalty"
    "1.500000"
  ];
assert vram32Selection.selectedModelTier.name == "vram32";
assert
  vram32Selection.selectedModels.coding.modelRef
  == "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL";
assert vram32Selection.selectedModels.coding.generation.temperature == 0.7;
assert vram32Selection.selectedModels.coding.generation.topP == 0.8;
assert vram32Selection.selectedModels.coding.generation.repetitionPenalty == 1.05;
assert vram16Selection.selectedModelTier.name == "vram16";
assert
  vram16Selection.selectedModels.coding.modelRef
  == "unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF:Q4_K_M";
assert vram16Selection.selectedModels.coding.maxContext == 131072;
assert vram16Selection.selectedModels.coding.generation == null;
assert vram16Selection.selectedModels.agentic.generation.presencePenalty == 1.5;
assert vram16Selection.selectedModels.reasoning.modelRef == "unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL";
assert vram16Selection.selectedModels.reasoning.generation.topP == 1.0;
assert vram16Selection.selectedModels.reasoning.generation.topK == 0;
assert
  vram16Selection.selectedModels.reasoning.llamaServerArgs == [
    "--ctx-size"
    "131072"
    "--cache-type-k"
    "q8_0"
    "--cache-type-v"
    "q8_0"
    "--temp"
    "1.000000"
    "--top-p"
    "1.000000"
    "--top-k"
    "0"
    "--repeat-penalty"
    "1.000000"
  ];
assert vram8Selection.selectedModelTier.name == "vram8";
assert
  vram8Selection.selectedModels.coding.modelRef
  == "unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF:Q4_K_M";
assert vram8Selection.selectedModels.coding.generation == null;
assert vram8Selection.selectedModels.agentic.modelRef == "unsloth/rnj-1-instruct-GGUF:UD-Q4_K_XL";
assert vram8Selection.selectedModels.agentic.maxContext == 32768;
assert vram8Selection.selectedModels.agentic.generation == null;
assert vram8Selection.selectedModels.reasoning.modelRef == "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
assert vram8Selection.selectedModels.reasoning.generation.presencePenalty == 1.5;
assert
  vram8Selection.selectedModels.agentic.llamaServerArgs == [
    "--ctx-size"
    "32768"
    "--cache-type-k"
    "q8_0"
    "--cache-type-v"
    "q8_0"
  ];
true
