{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  selection = modelPolicy.mkSelection { hostVramGiB = 96; };
in
assert selection.selectedModelTier.name == "vram64";
assert selection.selectedModels.coding == "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
assert selection.selectedModels.embedding == "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
true
