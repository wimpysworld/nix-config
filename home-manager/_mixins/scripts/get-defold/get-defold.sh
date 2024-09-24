#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail
DEFOLD_PATH="$HOME/Apps/Defold"

VER="$(curl -s https://api.github.com/repos/defold/defold/releases/latest | grep tag_name | grep -oP '(?<=": ")[^"]*')"
DEFOLD_URL="https://github.com/defold/defold/releases/download/$VER/Defold-x86_64-linux.tar.gz"
echo "Getting Defold $VER"
rm -f "$DEFOLD_PATH/Defold-x86_64-linux.tar.gz" 2>/dev/null
curl --progress-bar --location --output "$DEFOLD_PATH/Defold-x86_64-linux.tar.gz" "$DEFOLD_URL"
mkdir -p "$DEFOLD_PATH/Defold-$VER"
tar xf "$DEFOLD_PATH/Defold-x86_64-linux.tar.gz" --strip-components=1 -C "$DEFOLD_PATH/Defold-$VER"
rm -f "$DEFOLD_PATH/Defold-x86_64-linux.tar.gz" 2>/dev/null
echo "Defold extracted here: $DEFOLD_PATH/Defold-$VER"
echo "To create a container, run:"
echo "cd $DEFOLD_PATH"
echo "distrobox assemble create"
