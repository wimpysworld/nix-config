{ lib }:
let
  flake = builtins.getFlake (toString ../../../../../.);
  nixpkgs = flake.inputs.nixpkgs;

  evalFor =
    hostVramGiB:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../../../../lib/noughty
        {
          system.stateVersion = "25.11";
          noughty.host = {
            name = "testhost";
            kind = "computer";
            platform = "x86_64-linux";
            gpu.compute.vram = hostVramGiB;
            tags = [ "inference" ];
          };
        }
        ../preseed.nix
      ];
    };

  vram64Eval = evalFor 96;
  vram16Eval = evalFor 16;
  vram64Manifest = builtins.fromJSON (builtins.readFile vram64Eval.config.systemd.services.llama-models-preseed.environment.LLAMA_PRESEED_MODELS_JSON);
  vram16Manifest = builtins.fromJSON (builtins.readFile vram16Eval.config.systemd.services.llama-models-preseed.environment.LLAMA_PRESEED_MODELS_JSON);
  vram64Refs = map (entry: entry.modelRef) vram64Manifest;
  vram16Refs = map (entry: entry.modelRef) vram16Manifest;
in
assert builtins.elem "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL" vram64Refs;
assert builtins.elem "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" vram64Refs;
assert lib.length vram64Manifest == 4;
assert builtins.elem "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL" vram16Refs;
assert builtins.elem "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0" vram16Refs;
assert lib.length vram16Manifest == 3;
true
