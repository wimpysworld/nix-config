{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "goreleaser-mcp";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "goreleaser";
    repo = "mcp";
    rev = "v${version}";
    hash = "sha256-aGvdxAdsMKd81eVROxKbw5kRu4ng8qNvCWZGGzmUxME=";
  };

  vendorHash = "sha256-EkH6ghYfiDTd4jDwMCJFoWmgmzFb3dDWpmB2fq8sa+I=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.builtBy=nix"
  ];

  meta = with lib; {
    description = "The GoReleaser MCP server";
    homepage = "https://goreleaser.com/mcp";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
    mainProgram = "goreleaser-mcp";
  };
}
