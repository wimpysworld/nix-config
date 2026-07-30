# Upstream ships a flake.nix, but it pins version "0.0.0" and builds from a
# local path, so this builds from the release tag instead.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  libX11,
  makeWrapper,
  stdenv,
  wl-clipboard,
  xdg-utils,
}:

buildGoModule (finalAttrs: {
  pname = "slk";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "gammons";
    repo = "slk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jyKXzQQ/e5o4voj9KZM4WXvVPm6bnPBUjFPpIXaqKAk=";
  };

  vendorHash = "sha256-+eO1mgwuEkF+0rGEENzmJLOTaq82hP2LExGuOreypmc=";

  subPackages = [ "cmd/slk" ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ makeWrapper ];

  # Clipboard support comes from golang.design/x/clipboard, which needs cgo and
  # Xlib. The upstream release binaries set CGO_ENABLED=0, which silently drops
  # image paste; keep cgo on instead.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libX11 ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # The clipboard library reaches Xlib through dlopen("libX11.so"), so it never
  # becomes a link-time dependency and the runpath does not cover it. Under
  # Wayland slk reads the clipboard with wl-paste, and it opens links and files
  # with xdg-open.
  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/slk \
      --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libX11 ]} \
      --suffix PATH : ${
        lib.makeBinPath [
          wl-clipboard
          xdg-utils
        ]
      }
  '';

  meta = {
    description = "Keyboard-driven terminal user interface for Slack";
    homepage = "https://github.com/gammons/slk";
    changelog = "https://github.com/gammons/slk/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "slk";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
