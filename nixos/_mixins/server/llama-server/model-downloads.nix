{ lib }:
let
  entries = [
    {
      name = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
      value = {
        hfRepo = "Qwen/Qwen3-Embedding-0.6B-GGUF";
        primaryPath = "Qwen3-Embedding-0.6B-Q8_0.gguf";
        downloadPaths = [ "Qwen3-Embedding-0.6B-Q8_0.gguf" ];
      };
    }
    {
      name = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
      value = {
        hfRepo = "Qwen/Qwen3-Embedding-4B-GGUF";
        primaryPath = "Qwen3-Embedding-4B-Q8_0.gguf";
        downloadPaths = [ "Qwen3-Embedding-4B-Q8_0.gguf" ];
      };
    }
    {
      name = "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/Qwen3-Coder-Next-GGUF";
        primaryPath = "Qwen3-Coder-Next-UD-Q4_K_XL.gguf";
        downloadPaths = [ "Qwen3-Coder-Next-UD-Q4_K_XL.gguf" ];
      };
    }
    {
      name = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/Qwen3.5-35B-A3B-GGUF";
        primaryPath = "Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf";
        downloadPaths = [ "Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf" ];
      };
    }
    {
      name = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/Qwen3.5-9B-GGUF";
        primaryPath = "Qwen3.5-9B-UD-Q4_K_XL.gguf";
        downloadPaths = [ "Qwen3.5-9B-UD-Q4_K_XL.gguf" ];
      };
    }
    {
      name = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/gemma-4-26B-A4B-it-GGUF";
        primaryPath = "gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf";
        downloadPaths = [ "gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" ];
      };
    }
    {
      name = "unsloth/gemma-4-E2B-it-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/gemma-4-E2B-it-GGUF";
        primaryPath = "gemma-4-E2B-it-UD-Q4_K_XL.gguf";
        downloadPaths = [ "gemma-4-E2B-it-UD-Q4_K_XL.gguf" ];
      };
    }
    {
      name = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
      value = {
        hfRepo = "unsloth/gemma-4-E4B-it-GGUF";
        primaryPath = "gemma-4-E4B-it-UD-Q4_K_XL.gguf";
        downloadPaths = [ "gemma-4-E4B-it-UD-Q4_K_XL.gguf" ];
      };
    }
  ];

  entryNames = map (entry: entry.name) entries;
in
assert lib.length entryNames == lib.length (lib.unique entryNames);
builtins.listToAttrs entries
