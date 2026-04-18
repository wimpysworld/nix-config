{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  modelDownloads = import ../model-downloads.nix { inherit lib; };
  selectedRefs = modelPolicy.selectedModelReferences;

  validateRepoRelativePath =
    pathValue:
    pathValue != ""
    && !lib.hasPrefix "/" pathValue
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" pathValue
    );

  validateModelDownloads =
    refs: downloads:
    let
      missingRefs = lib.filter (ref: !builtins.hasAttr ref downloads) refs;
      invalidRefs = lib.filter (
        ref:
        let
          metadata = downloads.${ref};
          downloadPaths = metadata.downloadPaths or [ ];
        in
        !(metadata ? hfRepo && metadata ? primaryPath && metadata ? downloadPaths)
        || metadata.hfRepo == ""
        || metadata.primaryPath == ""
        || !(lib.hasSuffix ".gguf" metadata.primaryPath)
        || !(validateRepoRelativePath metadata.primaryPath)
        || downloadPaths == [ ]
        || lib.any (
          downloadPath: !(lib.hasSuffix ".gguf" downloadPath) || !(validateRepoRelativePath downloadPath)
        ) downloadPaths
        || !(builtins.elem metadata.primaryPath downloadPaths)
      ) refs;
    in
    {
      inherit missingRefs invalidRefs;
    };

  validation = validateModelDownloads selectedRefs modelDownloads;
  unmappedValidation = validateModelDownloads [ "broken:model" ] modelDownloads;
  invalidMetadataValidation = validateModelDownloads [ "broken:model" ] {
    "broken:model" = {
      hfRepo = "example/broken";
      primaryPath = "../broken.gguf";
      downloadPaths = [ "../broken.gguf" ];
    };
  };
in
assert validation.missingRefs == [ ];
assert validation.invalidRefs == [ ];
assert
  modelDownloads."Qwen/Qwen3-Embedding-4B-GGUF:Q8_0".primaryPath == "Qwen3-Embedding-4B-Q8_0.gguf";
assert unmappedValidation.missingRefs == [ "broken:model" ];
assert invalidMetadataValidation.invalidRefs == [ "broken:model" ];
true
