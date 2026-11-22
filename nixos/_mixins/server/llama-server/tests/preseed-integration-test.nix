{ lib }:
let
  runtime = import ../runtime.nix { inherit lib; };
  manifestFor =
    hostVramGiB:
    let
      selection = runtime.mkRuntime { inherit hostVramGiB; };
    in
    builtins.listToAttrs (
      map (entry: lib.nameValuePair entry.publicName entry) selection.selectedModelDownloads
    );
  vram64 = manifestFor 96;
  vram16 = manifestFor 16;
  vram8 = manifestFor 8;
  comparesQuant =
    name:
    vram64.${name}.hfRepo == vram16.${name}.hfRepo
    && vram64.${name}.revision == vram16.${name}.revision
    && vram64.${name}.revision != null
    && vram64.${name}.primaryPath != vram16.${name}.primaryPath;
in
assert builtins.attrNames vram64 == builtins.attrNames vram16;
assert comparesQuant "inkling-2-mini";
assert comparesQuant "qwen3.8-27b";
assert !(vram8 ? inkling-2-mini);
assert !(vram8 ? "qwen3.8-27b");
assert vram64."qwen3-embedding-0.6b" == vram16."qwen3-embedding-0.6b";
assert vram16."qwen3-embedding-0.6b" == vram8."qwen3-embedding-0.6b";
true
