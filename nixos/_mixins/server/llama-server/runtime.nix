{ lib }:
let
  defaultCacheRoot = "/var/lib/llama-models/huggingface";

  modelPolicy = import ./model-policy.nix { inherit lib; };
  modelDownloads = import ./model-downloads.nix;
  publicModelNames = lib.mapAttrs (_ref: download: download.publicName) modelDownloads;

  mkRepoCacheDirectory =
    cacheRoot: hfRepo: "${cacheRoot}/hub/models--${lib.replaceStrings [ "/" ] [ "--" ] hfRepo}";

  acceleratorArgs =
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
    assert model.mtpDraftTokens == null || (download.supportsMtp && model.singleSlot);
    {
      inherit
        acceleration
        cacheRoot
        download
        repoCacheDirectory
        role
        ;
      inherit (download)
        downloadPaths
        hfRepo
        primaryPath
        publicName
        revision
        supportsMtp
        ;
      isEmbedding = role == "embedding";
      inherit (model) modelRef;
      resolvedPrimaryPathPattern = "${repoCacheDirectory}/snapshots/${
        if download.revision == null then "*" else download.revision
      }/${download.primaryPath}";
      runtimeArgs =
        model.llamaServerArgs
        ++ roleArgs role
        ++ acceleratorArgs acceleration
        ++ lib.optionals (acceleration == "vulkan" && model.mtpDraftTokens != null) [
          "--spec-type"
          "draft-mtp"
          "--spec-draft-n-max"
          (toString model.mtpDraftTokens)
        ];
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
      selectedModelDownloads = map (modelRef: {
        inherit modelRef;
        inherit (modelDownloads.${modelRef})
          downloadPaths
          hfRepo
          primaryPath
          publicName
          revision
          ;
      }) selectedModelReferences;
      selectedPublicNames = map (download: download.publicName) selectedModelDownloads;
      selectedRuntimeModels = lib.mapAttrs (
        role: model:
        mkRuntimeModel {
          inherit acceleration cacheRoot role;
          inherit model;
        }
      ) selectedPolicy.selectedModels;
    in
    assert missingDownloads == [ ];
    assert lib.length selectedPublicNames == lib.length (lib.unique selectedPublicNames);
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
