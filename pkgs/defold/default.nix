{
  fetchurl,
  lib,
  makeDesktopItem,
  makeWrapper,
  stdenv,
  writeScript,
  freetype,
  git,
  gnused,
  jdk17,
  libdrm,
  libGL,
  libGLU,
  libogg,
  liboggz,
  libstdcxx5,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libXxf86vm,
  openal,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "defold";
  version = "1.9.3";

  src = fetchurl {
    url = "https://github.com/defold/defold/releases/download/${version}/Defold-x86_64-linux.tar.gz";
    hash = "sha256-JPPdiV4xP50i5Gq2QDqxpYjSrZ2ssGjft2w8vuQroKU=";
  };

  nativeBuildInputs = [
    gnused
    makeWrapper
  ];

  buildInputs = [
    freetype
    git
    jdk17
    libdrm
    libGL
    libGLU
    libogg
    liboggz
    libstdcxx5
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    libXrender
    libXtst
    libXxf86vm
    openal
    zlib
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    # Install Defold assets, but not the bundled JDK
    install -m 755 -D Defold $out/share/defold/Defold
    install -m 644 -D config $out/share/defold/config
    install -m 444 -D logo_blue.png $out/share/defold/logo_blue.png
    install -m 444 -D logo_blue.png \
        $out/share/icons/hicolor/512x512/apps/defold.png
    mkdir -p $out/share/defold/packages
    cp -a packages/defold-*.jar $out/share/defold/packages/
    runHook postInstall
  '';

  postFixup = ''
    # Devendor bundled JDK; it segfaults on NixOS
    JDK_VER=$(sed -n 's/.*\/\(jdk-[^/]*\).*/\1/p' $out/share/defold/config)
    ln -s ${jdk17} $out/share/defold/packages/${jdk17.name}
    sed -i "s|packages/$JDK_VER|packages/${jdk17.name}|" $out/share/defold/config
    # Disable editor updates; Nix will handle updates
    sed -i 's/\(channel = \).*/\1/' $out/share/defold/config
    # LD_LIBRARY_PATH: Ensure unpacked libraries/assets in ~/.Defold can find dependencies
    # PATH           : Ensure git is discovered by the Defold editor
    makeWrapper "$out/share/defold/Defold" "$out/bin/Defold" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libdrm
          libGL
          libGLU
          libogg
          liboggz
          libstdcxx5
          libX11
          libXcursor
          libXext
          libXi
          libXrandr
          libXrender
          libXtst
          libXxf86vm
          openal
        ]
      }" \
      --suffix PATH            : "${lib.makeBinPath [ git ]}"
  '';

  desktopItems = [
    (makeDesktopItem rec {
      name = "defold";
      desktopName = "Defold";
      keywords = [
        "Game"
        "Development"
      ];
      exec = "Defold";
      terminal = false;
      type = "Application";
      icon = "defold";
      categories = [
        "Development"
        "IDE"
      ];
      startupNotify = true;
    })
  ];

  passthru = {
    updateScript = writeScript "update-defold.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p github-release gnugrep gawk nix-update
      version=$(github-release info -u defold -r defold | grep -v -E 'alpha|beta|X.Y.Z|tags:' | head -n 1 | awk '{print $2}')
      nix-update defold --version "$version"
    '';
  };

  meta = {
    description = "A completely free to use game engine for development of desktop, mobile and web games.";
    homepage = "https://www.defold.com";
    license = lib.licenses.free;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "Defold";
  };
}
