#!/usr/bin/env bash

DOCKER_URL="https://desktop.docker.com/mac/stable/arm64/Docker.dmg"
DMG_FILE="Docker.dmg"
VOLUME_PATH="/Volumes/Docker"
APPLICATIONS_DIR="/Applications"

echo "Downloading Docker Desktop for Apple Silicon"
curl -L "$DOCKER_URL" -o "$DMG_FILE"

echo "Attaching $DMG_FILE..."
hdiutil attach "$DMG_FILE" -nobrowse

echo "Copying $DMG_FILE to $APPLICATIONS_DIR folder..."
cp -R "$VOLUME_PATH/Docker.app" "$APPLICATIONS_DIR"

echo "Ejecting $VOLUME_PATH..."
hdiutil detach "$VOLUME_PATH"

echo "Cleaning up $DMG_FILE..."
rm "$DMG_FILE"

echo "Docker has been installed. Please open Docker from the Applications folder to complete setup."
