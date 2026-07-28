{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "linear-tui";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "roeyazroel";
    repo = "linear-tui";
    rev = "v${finalAttrs.version}";
    hash = "sha256-kfDC2AVGJVilxcMWOnz+XvWBqOVFkt+ho8WhQWFQSY4=";
  };

  vendorHash = "sha256-+yC22fb6GtfAXLCIwwSXNRV7FIpelSx25KVa8NiD3Ew=";

  subPackages = [ "cmd/linear-tui" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${finalAttrs.version}"
  ];

  meta = {
    description = "Terminal user interface for the Linear issue tracker";
    homepage = "https://github.com/roeyazroel/linear-tui";
    changelog = "https://github.com/roeyazroel/linear-tui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "linear-tui";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
