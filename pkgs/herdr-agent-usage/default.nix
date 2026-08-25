{
  bash,
  buildGoModule,
  fetchFromGitHub,
  go_1_25,
  lib,
}:

let
  buildGo125Module = buildGoModule.override { go = go_1_25; };
in
buildGo125Module (finalAttrs: {
  pname = "herdr-agent-usage";
  version = "0.5.12";

  src = fetchFromGitHub {
    owner = "senna-lang";
    repo = "herdr-agent-usage";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ji59G80HOtkAZIxOCHxGP9wo165mWVBXwvhSnARlxmU=";
  };

  vendorHash = "sha256-cu6NdsSU1dzy3suV6IrQUpqjYEWAFf45t/mxo3dwAp4=";

  subPackages = [ "cmd/usagebar" ];

  buildInputs = [ bash ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  postInstall = ''
    pluginRoot="$out/share/herdr/plugins/usagebar"
    install -Dm644 "$src/herdr-plugin.toml" "$pluginRoot/herdr-plugin.toml"
    install -Dm755 -t "$pluginRoot/bin" "$src"/bin/*.sh
    ln -s "$out/bin/usagebar" "$pluginRoot/bin/usagebar"
    patchShebangs "$pluginRoot/bin"
    substituteInPlace "$pluginRoot/herdr-plugin.toml" \
      --replace-fail '"bash"' '"${bash}/bin/bash"'
  '';

  meta = {
    description = "Usage and rate-limit plugin for Herdr coding agent sessions";
    homepage = "https://github.com/senna-lang/herdr-agent-usage";
    changelog = "https://github.com/senna-lang/herdr-agent-usage/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "usagebar";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
