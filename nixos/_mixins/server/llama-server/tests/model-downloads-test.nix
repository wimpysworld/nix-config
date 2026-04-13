{ lib }:
let
  modelPolicy = import ../model-policy.nix { inherit lib; };
  modelDownloads = import ../model-downloads.nix { inherit lib; };
  selectedRefs = modelPolicy.selectedModelReferences;

  missingRefs = lib.filter (ref: !builtins.hasAttr ref modelDownloads) selectedRefs;
  invalidRefs = lib.filter (
    ref:
    let
      metadata = modelDownloads.${ref};
    in
    !(metadata ? hfRepo && metadata ? primaryPath && metadata ? downloadPaths)
    || metadata.downloadPaths == [ ]
  ) selectedRefs;
in
assert missingRefs == [ ];
assert invalidRefs == [ ];
assert modelDownloads."Qwen/Qwen3-Embedding-4B-GGUF:Q8_0".primaryPath == "Qwen3-Embedding-4B-Q8_0.gguf";
true
