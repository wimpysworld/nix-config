{ lib }:
let
  runtime = import ../runtime.nix { inherit lib; };

  vulkanRuntime = runtime.mkRuntime {
    acceleration = "vulkan";
    hostVramGiB = 96;
  };

  cudaRuntime = runtime.mkRuntime {
    acceleration = "cuda";
    hostVramGiB = 16;
  };
in
assert vulkanRuntime.selectedModelTier.name == "vram64";
assert vulkanRuntime.selectedRuntimeModels.coding.publicName == "qwen3-coder-next";
assert vulkanRuntime.selectedRuntimeModels.embedding.publicName == "qwen3-embedding-4b";
assert vulkanRuntime.selectedRuntimeModels.embedding.hfRepo == "Qwen/Qwen3-Embedding-4B-GGUF";
assert vulkanRuntime.selectedRuntimeModels.embedding.primaryPath == "Qwen3-Embedding-4B-Q8_0.gguf";
assert vulkanRuntime.selectedRuntimeModels.embedding.repoCacheDirectory == "/var/lib/llama-models/huggingface/hub/models--Qwen--Qwen3-Embedding-4B-GGUF";
assert vulkanRuntime.selectedRuntimeModels.embedding.resolvedPrimaryPathPattern == "/var/lib/llama-models/huggingface/hub/models--Qwen--Qwen3-Embedding-4B-GGUF/snapshots/*/Qwen3-Embedding-4B-Q8_0.gguf";
assert vulkanRuntime.selectedRuntimeModels.coding.runtimeArgs == [
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
  "40"
  "--repeat-penalty"
  "1.000000"
  "--min-p"
  "0.010000"
  "-fa"
  "1"
  "--mmap"
  "0"
];
assert vulkanRuntime.selectedRuntimeModels.embedding.runtimeArgs == [
  "--ctx-size"
  "40960"
  "--cache-type-k"
  "q8_0"
  "--cache-type-v"
  "q8_0"
  "--embedding"
  "--pooling"
  "last"
  "-fa"
  "1"
  "--mmap"
  "0"
];
assert lib.length vulkanRuntime.selectedModelDownloads == 5;
assert cudaRuntime.selectedModelTier.name == "vram16";
assert cudaRuntime.selectedRuntimeModels.reasoning.publicName == "gpt-oss-20b";
assert !(builtins.elem "-fa" cudaRuntime.selectedRuntimeModels.reasoning.runtimeArgs);
assert !(builtins.elem "--mmap" cudaRuntime.selectedRuntimeModels.reasoning.runtimeArgs);
true
