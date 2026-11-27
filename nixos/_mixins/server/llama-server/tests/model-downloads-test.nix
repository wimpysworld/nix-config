{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  modelDownloads = import ../model-downloads.nix;
  selectedRefs = modelPolicy.selectedModelReferences;

  validateRepoRelativePath =
    pathValue:
    pathValue != ""
    && !lib.hasPrefix "/" pathValue
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" pathValue
    );

  validateDownloadPath =
    path:
    (lib.hasSuffix ".gguf" path || lib.hasSuffix ".gguf_file" path) && validateRepoRelativePath path;

  validateModelDownloads =
    refs: downloads:
    let
      missingRefs = lib.filter (ref: !builtins.hasAttr ref downloads) refs;
      invalidRefs = lib.filter (
        ref:
        let
          metadata = downloads.${ref};
          downloadPaths = metadata.downloadPaths or [ ];
          projectorPath = metadata.projectorPath or null;
        in
        !(metadata ? hfRepo && metadata ? primaryPath && metadata ? downloadPaths)
        || metadata.hfRepo == ""
        || !(validateDownloadPath metadata.primaryPath)
        || downloadPaths == [ ]
        || !(lib.all validateDownloadPath downloadPaths)
        || !(builtins.elem metadata.primaryPath downloadPaths)
        || (
          projectorPath != null
          && (projectorPath == metadata.primaryPath || !(builtins.elem projectorPath downloadPaths))
        )
      ) refs;
    in
    {
      inherit missingRefs invalidRefs;
    };

  validation = validateModelDownloads selectedRefs modelDownloads;
  inklingDownloads = lib.filterAttrs (
    _: download: download.publicName == "inkling-2-mini"
  ) modelDownloads;
  mellumDownloads = lib.filterAttrs (
    _: download: download.publicName == "mellum2.1-12b"
  ) modelDownloads;
  pinnedDownloads = lib.filterAttrs (
    _: download:
    builtins.elem download.publicName [
      "inkling-2-mini"
      "qwen3.8-27b"
    ]
  ) modelDownloads;
  visionDownloads = lib.filterAttrs (
    _: download:
    builtins.elem download.publicName [
      "inkling-2-mini"
      "qwen3.5-9b"
      "qwen3.8-27b"
    ]
  ) modelDownloads;
  textOnlyDownloads = lib.filterAttrs (
    _: download:
    builtins.elem download.publicName [
      "mellum2.1-12b"
      "qwen3-embedding-0.6b"
    ]
  ) modelDownloads;
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
assert lib.subtractLists selectedRefs (builtins.attrNames modelDownloads) == [ ];
assert lib.all (
  download:
  lib.hasPrefix "Mainline_Support/" download.primaryPath
  && lib.hasSuffix ".gguf_file" download.primaryPath
) (lib.attrValues inklingDownloads);
assert builtins.length (lib.attrValues mellumDownloads) == 2;
assert lib.all (
  download:
  lib.hasPrefix "Mellum2.1-12B-A2.5B-Thinking-" download.primaryPath
  && lib.hasSuffix ".gguf" download.primaryPath
  && download.projectorPath == null
  && download.downloadPaths == [ download.primaryPath ]
  && !download.supportsMtp
) (lib.attrValues mellumDownloads);
assert lib.all (download: builtins.match "[a-f0-9]{40}" download.revision != null) (
  lib.attrValues pinnedDownloads
);
assert
  builtins.length (lib.attrValues visionDownloads)
  + builtins.length (lib.attrValues textOnlyDownloads)
  == builtins.length (lib.attrValues modelDownloads);
assert lib.all (download: download.projectorPath == "mmproj-BF16.gguf") (
  lib.attrValues visionDownloads
);
assert lib.all (download: download.projectorPath == null) (lib.attrValues textOnlyDownloads);
assert unmappedValidation.missingRefs == [ "broken:model" ];
assert invalidMetadataValidation.invalidRefs == [ "broken:model" ];
true
