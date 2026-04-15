{ lib }:
let
  runtime = import ../runtime.nix { inherit lib; };
  vram64Manifest = (runtime.mkRuntime {
    acceleration = null;
    hostVramGiB = 96;
  }).selectedModelDownloads;
  vram16Manifest = (runtime.mkRuntime {
    acceleration = null;
    hostVramGiB = 16;
  }).selectedModelDownloads;
  vram64Refs = map (entry: entry.modelRef) vram64Manifest;
  vram16Refs = map (entry: entry.modelRef) vram16Manifest;
in
assert builtins.elem "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL" vram64Refs;
assert builtins.elem "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" vram64Refs;
assert lib.length vram64Manifest == 5;
assert builtins.elem "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL" vram16Refs;
assert builtins.elem "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" vram16Refs;
assert lib.length vram16Manifest == 5;
true
