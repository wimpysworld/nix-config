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
  textOnlyModels = [
    "mellum2.1-12b"
    "qwen3-embedding-0.6b"
  ];
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
    "mellum2.1-12b"
    "qwen3-embedding-0.6b"
    "qwen3.5-9b"
  ];
assert
  builtins.attrNames vram16 == [
    "mellum2.1-12b"
    "qwen3-embedding-0.6b"
    "qwen3.5-9b"
  ];
assert vram22."mellum2.1-12b".modelRef == "JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF:Q8_0";
assert vram16."mellum2.1-12b".modelRef == "JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF:Q6_K";
assert vram22."mellum2.1-12b".downloadPaths == [ "Mellum2.1-12B-A2.5B-Thinking-Q8_0.gguf" ];
assert vram16."mellum2.1-12b".downloadPaths == [ "Mellum2.1-12B-A2.5B-Thinking-Q6_K.gguf" ];
assert vram22."qwen3.5-9b" == vram16."qwen3.5-9b";
assert vram64."qwen3-embedding-0.6b" == vram16."qwen3-embedding-0.6b";
assert lib.all (
  entry:
  (builtins.elem "mmproj-BF16.gguf" entry.downloadPaths)
  == !(builtins.elem entry.publicName textOnlyModels)
) (builtins.attrValues vram64 ++ builtins.attrValues vram22 ++ builtins.attrValues vram16);
true
