{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "wolfictl";
  version = "0.39.25";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name; # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "amd64"
        else
          throw "wolfictl: Unsupported architecture: ${currentArch}";

      # SHA256 sums from the release checksums.txt
      # https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_checksums.txt
      sha256s = {
        "darwin_amd64" = "d978605c057cafbb1407bedd022335c87a3da4f3f8a55f82023533500025ef12";
        "darwin_arm64" = "46230b4d0e04d3724e35221fddffdc0a79edbbba9e7fe788559e4ae2814bf84a";
        "linux_amd64" = "c2e4881912507cc74a0af8087e110bd7dd3b138bb2aca86b78d3464e8c4469e1";
        "linux_arm64" = "950be06d1063a0f1e3eaed156e48f40b646ba611c3aca7ffa43dca766fba802e";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_${currentSystem}_${archSuffix}_${version}_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "wolfictl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/wolfictl
    runHook postInstall
  '';

  meta = with lib; {
    description = "A CLI used to work with the Wolfi OSS project";
    homepage = "https://github.com/wolfi-dev/wolfictl";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
