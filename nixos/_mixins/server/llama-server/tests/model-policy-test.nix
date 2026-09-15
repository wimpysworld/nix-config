# Eval-time suite for the llama-server model policy and its runtime wiring.
# Assertions are property- and shape-based so that routine model refreshes do
# not trip constant pins, while tier-boundary selection, argument composition,
# and cache path construction stay covered. The one cross-tier constant that a
# property cannot express is pinned explicitly and noted in a comment.
{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  runtime = import ../runtime.nix { inherit lib; };

  inherit (modelPolicy) modelTiers;
  generationRoles = [
    "agentic"
    "coding"
    "reasoning"
    "smallMedia"
  ];

  isNumber = value: builtins.isInt value || builtins.isFloat value;
  allModels = lib.flatten (map (tier: lib.attrValues tier.models) modelTiers);
  allButLastTierIndex = lib.range 0 (lib.length modelTiers - 2);
  allTierIndex = lib.range 0 (lib.length modelTiers - 1);

  tierNamesAreUnique =
    lib.length (lib.unique (map (tier: tier.name) modelTiers)) == lib.length modelTiers;

  # The tier list must stay ordered from most to least VRAM, otherwise
  # `findFirst` in `mkSelection` resolves hosts to the wrong tier.
  tierMinimumsDecrease = lib.all (
    i: (builtins.elemAt modelTiers i).minVramGiB > (builtins.elemAt modelTiers (i + 1)).minVramGiB
  ) allButLastTierIndex;

  # A host with exactly a tier's minimum VRAM selects that tier, and a host one
  # GiB short falls through to the next tier down. The last tier doubles as the
  # fallback, so a host below its minimum still selects it.
  tierBoundariesHold = lib.all (
    i:
    let
      tier = builtins.elemAt modelTiers i;
      atMinimum = (modelPolicy.mkSelection { hostVramGiB = tier.minVramGiB; }).selectedModelTier;
      oneGiBShort = (modelPolicy.mkSelection { hostVramGiB = tier.minVramGiB - 1; }).selectedModelTier;
      nextTierDown =
        if i + 1 < lib.length modelTiers then builtins.elemAt modelTiers (i + 1) else lib.last modelTiers;
    in
    atMinimum.name == tier.name && oneGiBShort.name == nextTierDown.name
  ) allTierIndex;

  everyTierExposesAllRoles = lib.all (
    tier: lib.all (role: builtins.hasAttr role tier.models) (generationRoles ++ [ "embedding" ])
  ) modelTiers;

  # The three generation roles must never collapse onto one model within a tier.
  generationRolesAreDistinct = lib.all (
    tier:
    let
      refs = map (role: tier.models.${role}.modelRef) generationRoles;
    in
    lib.length (lib.unique refs) == lib.length generationRoles
  ) modelTiers;

  modelRefShape =
    model:
    let
      parts = lib.splitString ":" model.modelRef;
    in
    lib.length parts == 2 && lib.all (part: part != "") parts;

  # The policy standardises on one quantised KV cache for every model, so both
  # halves must agree and be set.
  kvCacheIsQuantised = model: model.kvCache.k == model.kvCache.v && model.kvCache.k != "";

  maxContextIsSane = model: builtins.isInt model.maxContext && model.maxContext > 0;

  generationShape =
    generation:
    generation == null
    || (
      isNumber generation.temperature
      && generation.temperature > 0.0
      && generation.temperature <= 2.0
      && isNumber generation.topP
      && generation.topP > 0.0
      && generation.topP <= 1.0
      && isNumber generation.topK
      && generation.topK >= 0
      && isNumber generation.repetitionPenalty
      && generation.repetitionPenalty > 0.0
      && (
        !(generation ? minP)
        || (isNumber generation.minP && generation.minP >= 0.0 && generation.minP < 1.0)
      )
      && (
        !(generation ? presencePenalty)
        || (isNumber generation.presencePenalty && generation.presencePenalty > 0.0)
      )
    );

  generationArgPairs =
    model:
    if model.generation == null then
      [ ]
    else
      [
        "--temp"
        (toString model.generation.temperature)
        "--top-p"
        (toString model.generation.topP)
        "--top-k"
        (toString model.generation.topK)
        "--repeat-penalty"
        (toString model.generation.repetitionPenalty)
      ]
      ++ lib.optionals (model.generation ? minP) [
        "--min-p"
        (toString model.generation.minP)
      ]
      ++ lib.optionals (model.generation ? presencePenalty) [
        "--presence-penalty"
        (toString model.generation.presencePenalty)
      ];

  # Context and KV cache flags lead, generation flags follow in the fixed
  # sampler order, and optional flags appear only when their field is set.
  expectedArgs =
    model:
    [
      "--ctx-size"
      (toString model.maxContext)
      "--cache-type-k"
      model.kvCache.k
      "--cache-type-v"
      model.kvCache.v
    ]
    ++ generationArgPairs model;

  argsComposeCorrectly = lib.all (model: model.llamaServerArgs == expectedArgs model) allModels;

  argsAreAllStrings = lib.all (model: lib.all builtins.isString model.llamaServerArgs) allModels;

  # The 8 GiB tier deliberately trades agentic context for a smaller model fit,
  # so keep this cross-tier difference pinned: a policy edit must not silently
  # equalise the agentic context window across tier boundaries.
  agenticContextDropsOnSmallestTier =
    (lib.last modelTiers).models.agentic.maxContext < (builtins.head modelTiers)
    .models.agentic.maxContext;

  vulkanRuntime = runtime.mkRuntime {
    acceleration = "vulkan";
    hostVramGiB = 96;
  };
  cudaRuntime = runtime.mkRuntime {
    acceleration = "cuda";
    hostVramGiB = 16;
  };

  expectedRepoCacheDirectory =
    cacheRoot: hfRepo: "${cacheRoot}/hub/models--${lib.replaceStrings [ "/" ] [ "--" ] hfRepo}";

  modelRefRepo = ref: builtins.elemAt (lib.splitString ":" ref) 0;

  acceleratorArgsFor =
    acceleration:
    if acceleration == "vulkan" then
      [
        "--flash-attn"
        "on"
        "--no-mmap"
      ]
    else
      [ ];
  roleArgsFor =
    role:
    if role == "embedding" then
      [
        "--embedding"
        "--pooling"
        "last"
      ]
    else
      [ ];

  # Policy arguments must lead, then role arguments, then accelerator
  # arguments, so llama-swap always sees a predictable command tail.
  runtimeArgsCompose =
    rt:
    lib.all (
      model:
      model.runtimeArgs
      == model.llamaServerArgs ++ roleArgsFor model.role ++ acceleratorArgsFor rt.acceleration
    ) (lib.attrValues rt.selectedRuntimeModels);

  cachePathsResolve =
    model:
    let
      expectedCacheDirectory = expectedRepoCacheDirectory model.cacheRoot model.hfRepo;
    in
    model.repoCacheDirectory == expectedCacheDirectory
    && model.resolvedPrimaryPathPattern == "${expectedCacheDirectory}/snapshots/*/${model.primaryPath}";

  downloadMetadataConsistent =
    model:
    model.hfRepo == modelRefRepo model.modelRef
    && model.primaryPath != ""
    && builtins.elem model.primaryPath model.downloadPaths;

  publicNamesAreUsable =
    rt:
    let
      names = map (model: model.publicName) (lib.attrValues rt.selectedRuntimeModels);
    in
    lib.all (name: name != "") names && lib.length (lib.unique names) == lib.length names;

  downloadsCoverSelection =
    rt:
    lib.length rt.selectedModelDownloads == lib.length (lib.attrValues rt.selectedRuntimeModels)
    &&
      lib.length (lib.unique (map (download: download.hfRepo) rt.selectedModelDownloads))
      == lib.length rt.selectedModelDownloads;

  vulkanCoding = vulkanRuntime.selectedRuntimeModels.coding;
  vulkanEmbedding = vulkanRuntime.selectedRuntimeModels.embedding;
  cudaReasoning = cudaRuntime.selectedRuntimeModels.reasoning;
in
assert tierNamesAreUnique;
assert tierMinimumsDecrease;
assert tierBoundariesHold;
assert everyTierExposesAllRoles;
assert generationRolesAreDistinct;
assert lib.all modelRefShape allModels;
assert lib.all kvCacheIsQuantised allModels;
assert lib.all maxContextIsSane allModels;
assert lib.all (model: generationShape model.generation) allModels;
assert argsComposeCorrectly;
assert argsAreAllStrings;
assert agenticContextDropsOnSmallestTier;
assert runtimeArgsCompose vulkanRuntime;
assert runtimeArgsCompose cudaRuntime;
assert lib.all cachePathsResolve (lib.attrValues vulkanRuntime.selectedRuntimeModels);
assert lib.all cachePathsResolve (lib.attrValues cudaRuntime.selectedRuntimeModels);
assert lib.all downloadMetadataConsistent (lib.attrValues vulkanRuntime.selectedRuntimeModels);
assert lib.all downloadMetadataConsistent (lib.attrValues cudaRuntime.selectedRuntimeModels);
assert publicNamesAreUsable vulkanRuntime;
assert publicNamesAreUsable cudaRuntime;
assert downloadsCoverSelection vulkanRuntime;
assert downloadsCoverSelection cudaRuntime;
# Embedding models carry no generation block, so no sampler flags may leak in.
assert vulkanEmbedding.generation == null;
assert !builtins.elem "--temp" vulkanEmbedding.runtimeArgs;
assert
  lib.take 3 (lib.reverseList vulkanCoding.runtimeArgs) == [
    "--no-mmap"
    "on"
    "--flash-attn"
  ];
assert !(builtins.elem "--flash-attn" cudaReasoning.runtimeArgs);
assert !(builtins.elem "--no-mmap" cudaReasoning.runtimeArgs);
true
