{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openhue-cli";
  version = "0.23";

  src = fetchurl (
    let
      system = stdenv.hostPlatform.system;
      sources = {
        x86_64-linux = {
          name = "openhue_Linux_x86_64.tar.gz";
          hash = "sha256-eCx4rF1ZRkgO7iwR8LjRDIc6FWtShE5/edKaD+b4AvY=";
        };
        aarch64-linux = {
          name = "openhue_Linux_arm64.tar.gz";
          hash = "sha256-Xx5dQBqF8yPmj+rxX69bplecZfKMUp1WN/zohd9qhKY=";
        };
      };
      source = sources.${system} or (throw "openhue-cli: unsupported system ${system}");
    in
    {
      url = "https://github.com/openhue/openhue-cli/releases/download/${finalAttrs.version}/${source.name}";
      inherit (source) hash;
    }
  );

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 openhue $out/bin/openhue

    runHook postInstall
  '';

  meta = {
    description = "Command-line interface for interacting with Philips Hue smart lighting systems";
    homepage = "https://github.com/openhue/openhue-cli";
    license = lib.licenses.asl20;
    mainProgram = "openhue";
    platforms = lib.platforms.linux;
  };
})
