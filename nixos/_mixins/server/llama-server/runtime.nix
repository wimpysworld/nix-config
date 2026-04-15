{ lib }:
let
  defaultCacheRoot = "/var/lib/llama-models/huggingface";

  modelPolicy = import ./model-policy.nix { inherit lib; };
  modelDownloads = import ./model-downloads.nix { inherit lib; };

  publicModelNames = builtins.listToAttrs [
    {
      name = "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
      value = "qwen3-embedding-0.6b";
    }
    {
      name = "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0";
      value = "qwen3-embedding-4b";
    }
    {
      name = "unsloth/rnj-1-instruct-GGUF:UD-Q4_K_XL";
      value = "rnj-1-8b";
    }
    {
      name = "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL";
      value = "qwen3-coder-next";
    }
    {
      name = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL";
      value = "qwen3-coder-30b-a3b";
    }
    {
      name = "unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF:Q4_K_M";
      value = "qwen2.5-coder-14b";
    }
    {
      name = "unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF:Q4_K_M";
      value = "qwen2.5-coder-7b";
    }
    {
      name = "unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL";
      value = "qwen3.5-35b-a3b";
    }
    {
      name = "unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL";
      value = "qwen3.5-9b";
    }
    {
      name = "unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL";
      value = "gpt-oss-20b";
    }
    {
      name = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
      value = "gemma4-26b";
    }
    {
      name = "unsloth/gemma-4-E2B-it-GGUF:UD-Q6_K_XL";
      value = "gemma4-e2b";
    }
    {
      name = "unsloth/gemma-4-E4B-it-GGUF:UD-Q6_K_XL";
      value = "gemma4-e4b";
    }
  ];

  mkRepoCacheDirectory =
    cacheRoot: hfRepo: "${cacheRoot}/hub/models--${lib.replaceStrings [ "/" ] [ "--" ] hfRepo}";

  acceleratorArgs =
    acceleration:
    if acceleration == "vulkan" then
      [
        "-fa"
        "1"
        "--mmap"
        "0"
      ]
    else
      [ ];

  roleArgs =
    role:
    if role == "embedding" then
      [
        "--embedding"
        "--pooling"
        "last"
      ]
    else
      [ ];

  mkRuntimeModel =
    {
      acceleration,
      cacheRoot,
      role,
      model,
    }:
    let
      download = modelDownloads.${model.modelRef};
      repoCacheDirectory = mkRepoCacheDirectory cacheRoot download.hfRepo;
    in
    {
      inherit
        acceleration
        cacheRoot
        download
        repoCacheDirectory
        role
        ;
      inherit (download) downloadPaths;
      inherit (download) hfRepo;
      isEmbedding = role == "embedding";
      inherit (model) modelRef;
      inherit (download) primaryPath;
      publicName = publicModelNames.${model.modelRef};
      resolvedPrimaryPathPattern = "${repoCacheDirectory}/snapshots/*/${download.primaryPath}";
      runtimeArgs = model.llamaServerArgs ++ roleArgs role ++ acceleratorArgs acceleration;
    }
    // model;
in
{
  inherit defaultCacheRoot publicModelNames;

  mkRuntime =
    {
      acceleration ? null,
      cacheRoot ? defaultCacheRoot,
      hostVramGiB ? 0,
    }:
    let
      selectedPolicy = modelPolicy.mkSelection { inherit hostVramGiB; };
      selectedModelReferences = lib.unique (
        map (model: model.modelRef) (builtins.attrValues selectedPolicy.selectedModels)
      );
      missingDownloads = lib.filter (ref: !builtins.hasAttr ref modelDownloads) selectedModelReferences;
      missingPublicNames = lib.filter (
        ref: !builtins.hasAttr ref publicModelNames
      ) selectedModelReferences;
      selectedModelDownloads = map (
        modelRef:
        modelDownloads.${modelRef}
        // {
          inherit modelRef;
          publicName = publicModelNames.${modelRef};
        }
      ) selectedModelReferences;
      selectedRuntimeModels = lib.mapAttrs (
        role: model:
        mkRuntimeModel {
          inherit acceleration cacheRoot role;
          inherit model;
        }
      ) selectedPolicy.selectedModels;
    in
    assert missingDownloads == [ ];
    assert missingPublicNames == [ ];
    {
      inherit
        acceleration
        cacheRoot
        selectedModelDownloads
        selectedRuntimeModels
        ;
      inherit (selectedPolicy)
        modelMatrix
        modelTiers
        selectedModelTier
        selectedModels
        ;
    };
}
