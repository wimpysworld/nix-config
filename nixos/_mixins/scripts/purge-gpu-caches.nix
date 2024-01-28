{ pkgs }:

pkgs.writeScriptBin "purge-gpu-caches" ''
#!${pkgs.stdenv.shell}
CACHES=$(${pkgs.fd}/bin/fd GPUCache "$HOME"/.config)

# Set IFS to split on newline instead of space
IFS=$'\n'

for CACHE in $CACHES; do
    ${pkgs.coreutils-full}/bin/echo "Purging $CACHE"
    ${pkgs.coreutils-full}/bin/rm -v "$CACHE"*
done
''
