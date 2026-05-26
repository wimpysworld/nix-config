{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "tcount";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "lancekrogers";
    repo = "tcount";
    rev = "v${finalAttrs.version}";
    hash = "sha256-p2p/mZeWiZhWEissNqGKcvWLScspy/0YQxWaTuQppuo=";
  };

  vendorHash = "sha256-wdHrULL+aHUBJqab8yhJ9IZu+razp5X3N20I/lO2L84=";

  subPackages = [ "cmd/tcount" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  meta = {
    description = "Fast, zero-network token counter for LLM workflows";
    homepage = "https://github.com/lancekrogers/tcount";
    license = lib.licenses.mit;
    mainProgram = "tcount";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
