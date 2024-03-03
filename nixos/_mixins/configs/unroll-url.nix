{ pkgs }:

pkgs.writeScriptBin "unroll-url" ''
#!${pkgs.stdenv.shell}

if [ -n "$1" ]; then
  ${pkgs.curlMinimal}/bin/curl -w "%{url_effective}\n" -I -L -s -S "$1" -o /dev/null
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! Please provide a URL"
  exit 1
fi
''
