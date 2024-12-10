{ pkgs }:
# This is a stub package for Cider (Apple Music client)
# Used in CI/testing environments where the actual proprietary binary cannot be distributed
pkgs.writeShellApplication {
  name = "cider";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    echo "cider (stub package)"
  '';

  meta = with pkgs.lib; {
    description = "Stub package for Cider Apple Music client";
    longDescription = ''
      This is a stub package that stands in for the proprietary Cider Apple Music client.
      It is used in CI environments and testing where the actual application binary
      cannot be distributed. For actual use, you should build the real package locally
      with the genuine application.
    '';
    license = licenses.free;
    platforms = platforms.all;
    maintainers = [ flexiondotorg ];
  };
}
