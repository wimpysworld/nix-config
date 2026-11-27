# Eval-time suite for the llama-server model policy and its runtime wiring.
# Run directly with nix eval to check tier boundaries, argument composition,
# and cache paths without evaluating a host configuration.
{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  runtime = import ../runtime.nix { inherit lib; };

  inherit (modelPolicy) modelMatrix modelTiers;
  textRoles = [
    "dense"
    "moe"
  ];
  commonRoles = [
    "embedding"
    "smallMedia"
  ];
  textTiers = lib.init modelTiers;

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

  tierRolesHold =
    lib.all (
      tier:
      let
        expectedRoles = textRoles ++ commonRoles ++ lib.optional (tier.name == "vram16") "utility";
      in
      builtins.attrNames tier.models == lib.sort builtins.lessThan expectedRoles
    ) textTiers
    && builtins.attrNames (lib.last modelTiers).models == commonRoles;

  modelRolesAreDistinct = lib.all (
    tier:
    let
      refs = map (model: model.modelRef) (lib.attrValues tier.models);
    in
    lib.length (lib.unique refs) == lib.length refs
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
        || (isNumber generation.presencePenalty && generation.presencePenalty >= 0.0)
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
    ++ generationArgPairs model
    ++ lib.optionals (model.reasoning != null) [
      "--reasoning"
      model.reasoning
    ]
    ++ lib.optionals (model.reasoningEffort != null) [
      "--reasoning-effort"
      model.reasoningEffort
    ]
    ++ lib.optionals model.singleSlot [
      "--parallel"
      "1"
      "--no-context-shift"
    ]
    ++ lib.optionals (model.microBatchSize != null) [
      "--ubatch-size"
      (toString model.microBatchSize)
    ];

  argsComposeCorrectly = lib.all (model: model.llamaServerArgs == expectedArgs model) allModels;

  argsAreAllStrings = lib.all (model: lib.all builtins.isString model.llamaServerArgs) allModels;

  textContextShrinksOnLowerTiers = lib.all (
    role:
    let
      contexts = map (tier: tier.models.${role}.maxContext) textTiers;
    in
    lib.head contexts > lib.last contexts && contexts == lib.sort (a: b: a > b) contexts
  ) textRoles;

  eachTextModelUsesOneSlot = lib.all (
    tier: lib.all (role: tier.models.${role}.singleSlot) textRoles
  ) textTiers;

  embeddingIsUniform = lib.all (
    tier: tier.models.embedding == modelMatrix.vram8.models.embedding
  ) modelTiers;

  vulkanRuntime = runtime.mkRuntime {
    acceleration = "vulkan";
    hostVramGiB = 96;
  };
  lowerVulkanRuntime = runtime.mkRuntime {
    acceleration = "vulkan";
    hostVramGiB = 32;
  };
  highCudaRuntime = runtime.mkRuntime {
    acceleration = "cuda";
    hostVramGiB = 64;
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
        "--load-mode"
        "none"
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

  mtpArgsFor =
    rt: model:
    lib.optionals (rt.acceleration == "vulkan" && model.mtpDraftTokens != null) [
      "--spec-type"
      "draft-mtp"
      "--spec-draft-n-max"
      (toString model.mtpDraftTokens)
    ];

  # Keep the runtime argument order stable.
  runtimeArgsCompose =
    rt:
    lib.all (
      model:
      model.runtimeArgs == model.llamaServerArgs
      ++ roleArgsFor model.role
      ++ acceleratorArgsFor rt.acceleration
      ++ mtpArgsFor rt model
    ) (lib.attrValues rt.selectedRuntimeModels);

  cachePathsResolve =
    model:
    let
      expectedCacheDirectory = expectedRepoCacheDirectory model.cacheRoot model.hfRepo;
      snapshot = if model.revision == null then "*" else model.revision;
    in
    model.repoCacheDirectory == expectedCacheDirectory
    &&
      model.resolvedPrimaryPathPattern
      == "${expectedCacheDirectory}/snapshots/${snapshot}/${model.primaryPath}";

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

  vulkanMoe = vulkanRuntime.selectedRuntimeModels.moe;
  vulkanDense = vulkanRuntime.selectedRuntimeModels.dense;
  vulkanEmbedding = vulkanRuntime.selectedRuntimeModels.embedding;
  cudaDense = cudaRuntime.selectedRuntimeModels.dense;
  cudaUtility = cudaRuntime.selectedRuntimeModels.utility;
  usesMtp = model: builtins.elem "--spec-type" model.runtimeArgs;
in
assert tierNamesAreUnique;
assert tierMinimumsDecrease;
assert tierBoundariesHold;
assert tierRolesHold;
assert modelRolesAreDistinct;
assert lib.all modelRefShape allModels;
assert lib.all kvCacheIsQuantised allModels;
assert lib.all maxContextIsSane allModels;
assert lib.all (model: generationShape model.generation) allModels;
assert argsComposeCorrectly;
assert argsAreAllStrings;
assert lib.all (
  tier: tier.models.smallMedia.reasoning == "on" && tier.models.smallMedia.generation.minP == 0.0
) modelTiers;
assert lib.all (tier: tier.models.dense.reasoningEffort == "medium") textTiers;
assert lib.all (tier: tier.models.moe.reasoningEffort == null) textTiers;
assert textContextShrinksOnLowerTiers;
assert eachTextModelUsesOneSlot;
assert embeddingIsUniform;
assert lib.all runtimeArgsCompose [
  vulkanRuntime
  lowerVulkanRuntime
  highCudaRuntime
  cudaRuntime
];
assert lib.all cachePathsResolve (lib.attrValues vulkanRuntime.selectedRuntimeModels);
assert lib.all cachePathsResolve (lib.attrValues cudaRuntime.selectedRuntimeModels);
assert lib.all downloadMetadataConsistent (lib.attrValues vulkanRuntime.selectedRuntimeModels);
assert lib.all downloadMetadataConsistent (lib.attrValues cudaRuntime.selectedRuntimeModels);
assert publicNamesAreUsable vulkanRuntime;
assert publicNamesAreUsable cudaRuntime;
assert downloadsCoverSelection vulkanRuntime;
assert downloadsCoverSelection cudaRuntime;
# Embedding models carry no generation block, so sampler flags must stay absent.
assert vulkanEmbedding.generation == null;
assert !builtins.elem "--temp" vulkanEmbedding.runtimeArgs;
assert !builtins.elem "--reasoning" vulkanEmbedding.runtimeArgs;
assert !builtins.elem "--reasoning-effort" vulkanEmbedding.runtimeArgs;
assert
  lib.take 4 (lib.reverseList vulkanMoe.runtimeArgs) == [
    "none"
    "--load-mode"
    "on"
    "--flash-attn"
  ];
assert !(builtins.elem "--flash-attn" cudaDense.runtimeArgs);
assert !(builtins.elem "--load-mode" cudaDense.runtimeArgs);
assert cudaUtility.publicName == "qwen3.5-9b";
assert cudaUtility.modelRef == "unsloth/Qwen3.5-9B-MTP-GGUF:UD-Q4_K_XL";
assert cudaUtility.maxContext == 131072;
assert cudaUtility.reasoning == "off";
assert !cudaUtility.singleSlot;
assert cudaUtility.supportsMtp;
assert cudaUtility.generation.temperature == 0.7;
assert cudaUtility.generation.topP == 0.8;
assert cudaUtility.generation.presencePenalty == 1.5;
assert !(vulkanRuntime.selectedRuntimeModels ? utility);
assert vulkanDense.supportsMtp;
assert !vulkanMoe.supportsMtp;
assert usesMtp vulkanDense;
assert !usesMtp vulkanMoe;
assert !usesMtp cudaUtility;
assert !usesMtp lowerVulkanRuntime.selectedRuntimeModels.dense;
assert !usesMtp highCudaRuntime.selectedRuntimeModels.dense;
true
