{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  selection = modelPolicy.mkSelection { hostVramGiB = 96; };
  vram32Selection = modelPolicy.mkSelection { hostVramGiB = 32; };
  vram16Selection = modelPolicy.mkSelection { hostVramGiB = 16; };
  vram8Selection = modelPolicy.mkSelection { hostVramGiB = 8; };
in
assert selection.selectedModelTier.name == "vram64";
assert selection.selectedModels.coding == "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.agentic == "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.reasoning == "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.embedding == "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
assert vram32Selection.selectedModelTier.name == "vram32";
assert vram32Selection.selectedModels.coding == "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL";
assert vram16Selection.selectedModelTier.name == "vram16";
assert vram16Selection.selectedModels.coding == "unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF:Q4_K_M";
assert vram16Selection.selectedModels.reasoning == "unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL";
assert vram8Selection.selectedModelTier.name == "vram8";
assert vram8Selection.selectedModels.coding == "unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF:Q4_K_M";
assert vram8Selection.selectedModels.agentic == "EssentialAI/rnj-1-instruct-GGUF:Q4_K_M";
assert vram8Selection.selectedModels.reasoning == "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
true
