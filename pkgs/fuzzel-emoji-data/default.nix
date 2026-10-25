{
  lib,
  fetchurl,
  python3,
  stdenvNoCC,
}:
let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  fetched = lib.mapAttrs (_: source: fetchurl { inherit (source) url hash; }) sources;
in
stdenvNoCC.mkDerivation {
  pname = "fuzzel-emoji-data";
  version = sources.unicode.version;

  src = ./.;
  nativeBuildInputs = [ python3 ];
  dontConfigure = true;
  doCheck = true;

  buildPhase = ''
    runHook preBuild
    python generate.py \
      --unicode ${fetched.unicode} \
      --emojibase ${fetched.emojibase} \
      --emojilib ${fetched.emojilib} \
      --unicode-license ${fetched.unicodeLicense} \
      --sources sources.json \
      --overrides keyword-overrides.json \
      --output generated
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    EMOJI_MASTER="$PWD/generated/master.json" \
      EMOJI_UNICODE=${fetched.unicode} \
      python -m unittest -v test_generator.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fuzzel-emoji"
    cp -r generated/. "$out/share/fuzzel-emoji/"
    cp schema.json sources.json keyword-overrides.json README.md "$out/share/fuzzel-emoji/"
    runHook postInstall
  '';

  meta = {
    description = "Unicode emoji catalogue and search keywords for Fuzzel";
    license = [
      lib.licenses.mit
      lib.licenses.unicode-30
    ];
    platforms = lib.platforms.all;
  };
}
