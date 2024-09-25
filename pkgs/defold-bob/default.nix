{
  fetchurl,
  lib,
  makeWrapper,
  pkgs,
  stdenv,
  writeShellApplication,
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

  nativeBuildInputs = [
    makeWrapper
  ];

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
    mkdir -p $out/bin
    echo "#!/usr/bin/env bash" > $out/bin/defold-bob
    echo "exec ${jdk17}/bin/java -jar $out/bob.jar \$@" >> $out/bin/defold-bob
    chmod 755 $out/bin/defold-bob
    runHook postInstall
  '';

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
