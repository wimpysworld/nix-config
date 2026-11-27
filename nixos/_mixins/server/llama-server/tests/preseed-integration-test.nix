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
  vram32 = manifestFor 32;
  vram22 = manifestFor 24;
  vram16 = manifestFor 16;
in
assert vram64 == vram32;
assert
  builtins.attrNames vram64 == [
    "inkling-2-mini"
    "qwen3-embedding-0.6b"
    "qwen3.8-27b"
  ];
assert
  builtins.attrNames vram22 == [
    "inkling-2-mini"
    "qwen3-embedding-0.6b"
    "qwen3.5-9b"
  ];
assert
  builtins.attrNames vram16 == [
    "qwen3-embedding-0.6b"
    "qwen3.5-9b"
  ];
assert vram64."inkling-2-mini" == vram22."inkling-2-mini";
assert vram22."qwen3.5-9b" == vram16."qwen3.5-9b";
assert vram64."qwen3-embedding-0.6b" == vram16."qwen3-embedding-0.6b";
assert lib.all (
  entry:
  (builtins.elem "mmproj-BF16.gguf" entry.downloadPaths)
  == (entry.publicName != "qwen3-embedding-0.6b")
) (builtins.attrValues vram64 ++ builtins.attrValues vram16);
true
