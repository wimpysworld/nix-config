{ lib
, stdenv
, darwin
, fetchFromGitHub
, copyDesktopItems
, makeDesktopItem
, makeWrapper
, libxkbcommon
, openssl
, pkg-config
, rustPlatform
, vulkan-loader
, wayland
, xorg
}:

rustPlatform.buildRustPackage rec {
  pname = "halloy";
  version = "2024.3";

  src = fetchFromGitHub {
    owner = "squidowl";
    repo = "halloy";
    rev = "refs/tags/${version}";
    hash = "sha256-9yEkM65c8R71oQ0C54xZqwRh609+HSaq4Hb8izNM52A=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "iced-0.12.0" = "sha256-LtmAJDUMp42S4E+CjOM6Q7doAKOZkmJCN/49gsq3v/A=";
      "winit-0.29.10" = "sha256-YoXJEvEhMvk3pK5EbXceVFeJEJLL6KTjiw0kBJxgHIE=";
    };
  };

  nativeBuildInputs = [
    copyDesktopItems
    pkg-config
  ] ++ lib.optionals stdenv.isLinux [
    makeWrapper
  ];

  buildInputs = [
    libxkbcommon
    openssl
    vulkan-loader
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.AppKit
    darwin.apple_sdk.frameworks.CoreFoundation
    darwin.apple_sdk.frameworks.CoreGraphics
    darwin.apple_sdk.frameworks.Foundation
    darwin.apple_sdk.frameworks.Metal
    darwin.apple_sdk.frameworks.QuartzCore
    darwin.apple_sdk.frameworks.Security
  ] ++ lib.optionals stdenv.isLinux [
    wayland
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "org.squidowl.halloy";
      desktopName = "Halloy";
      comment = "IRC client written in Rust";
      icon = "org.squidowl.halloy";
      exec = pname;
      terminal = false;
      mimeTypes = [ "x-scheme-handler/irc" "x-scheme-handler/ircs" ];
      categories = [ "Network" "IRCClient" ];
      keywords = [ "IM" "Chat" ];
      startupWMClass = "org.squidowl.halloy";
    })
  ];

  # Force linking to to libwayland-client, which is always dlopen()ed
  # except by the obscure winit backend.
  RUSTFLAGS = (lib.optionals stdenv.isLinux) map (a: "-C link-arg=${a}") [
    "-Wl,--push-state,--no-as-needed"
    "-lwayland-client"
    "-Wl,--pop-state"
  ];

  postInstall = ''
    install -Dm644 assets/linux/org.squidowl.halloy.png $out/share/icons/hicolor/128x128/apps/org.squidowl.halloy.png
  '' + lib.optionalString stdenv.isLinux ''
    wrapProgram "$out/bin/halloy" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
        libxkbcommon
        vulkan-loader
      ]}
  '';

  meta = with lib; {
    description = "IRC application";
    homepage = "https://github.com/squidowl/halloy";
    changelog = "https://github.com/squidowl/halloy/blob/${version}/CHANGELOG.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ fab ];
    mainProgram = "halloy";
  };
}
