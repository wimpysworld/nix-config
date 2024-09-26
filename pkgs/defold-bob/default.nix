{
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
  writeScript,
  jdk17,
  libXext,
  libXtst,
}:
stdenv.mkDerivation rec {
  pname = "defold-bob";
  version = "1.9.3";

  src = fetchurl {
    url = "https://github.com/defold/defold/releases/download/${version}/bob.jar";
    hash = "sha256-b/PFgm7IrSTaKTcwTzntoxGd5KtGsgWvq2ZTteLw6GA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    jdk17
    libXext
    libXtst
  ];

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -m 444 -D $src $out/bob.jar
    makeWrapper ${jdk17}/bin/java $out/bin/defold-bob \
      --add-flags "-jar $out/bob.jar"
    runHook postInstall
  '';

  passthru = {
    updateScript = writeScript "update-defold-bob.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p github-release gnugrep gawk nix-update
      version=$(github-release info -u defold -r defold | grep -v -E 'alpha|beta|X.Y.Z|tags:' | head -n 1 | awk '{print $2}')
      nix-update defold-bob --version "$version"
    '';
  };

  meta = {
    description = "Bob is a command line tool for building Defold projects outside of the normal editor workflow.";
    homepage = "https://defold.com/manuals/bob/";
    license = lib.licenses.free;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "defold-bob";
  };
}
