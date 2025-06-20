#!/usr/bin/env bash

set -euo pipefail

VERSION="0.2.91"

SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
# Determine architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="x86_64"
        ;;
    arm64|aarch64)
        ARCH_SUFFIX="arm64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

PLATFORM_KEY="${SYSTEM}_${ARCH_SUFFIX}"

# Download URL
URL="https://dl.enforce.dev/chainctl/${VERSION}/chainctl_${SYSTEM}_${ARCH_SUFFIX}"

# Install directory
INSTALL_DIR="${HOME}/.local/go/bin"
CHAINCTL_PATH="${INSTALL_DIR}/chainctl"
SYMLINK_PATH="${INSTALL_DIR}/docker-credential-cgr"

echo "Installing chainctl ${VERSION} for ${PLATFORM_KEY}..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download chainctl
if curl -fL --progress-bar -o "$CHAINCTL_PATH" "$URL"; then
    chmod +x "$CHAINCTL_PATH"
    # Create symlink to docker-credential-cgr
    ln -sf "$CHAINCTL_PATH" "$SYMLINK_PATH"
    echo "Installation complete!"
    echo "- $CHAINCTL_PATH"
    echo "- $SYMLINK_PATH"
else
    echo "ERROR! Failed to download 'chainctl' from $URL"
    exit 1
fi
