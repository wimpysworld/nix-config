{ pkgs }:
# This is a stub package for Cider (Apple Music client)
# Used in CI/testing environments where the actual proprietary binary cannot be distributed
pkgs.writeShellApplication {
  name = "pico8";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    echo "pico8 (stub package)"
  '';

  meta = with pkgs.lib; {
    description = "Stub package for PICO-8";
    longDescription = ''
      This is a stub package that stands in for the proprietary PICO-8 fantasy console.
      It is used in CI environments and testing where the actual application binary
      cannot be distributed. For actual use, you should build the real package locally
      with the genuine application.
    '';
    license = licenses.free;
    platforms = platforms.all;
    maintainers = [ flexiondotorg ];
  };
}
