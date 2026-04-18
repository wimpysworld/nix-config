#!/usr/bin/env bash
set -euo pipefail

# Download Piper southern_english_female-high voice from Hugging Face
# Voice commit hash for reproducibility: 5512791644e2148e4be301d4c7fc2a4bf51a5057
# This commit hash is immutable - downloading from it provides supply-chain security

VOICE_DIR="${1:-$HOME/.local/share/piper}"
mkdir -p "$VOICE_DIR"

echo "Downloading southern_english_female-high voice..."

# Use immutable commit hash URL for reproducibility and supply-chain security
# https://huggingface.co/rhasspy/piper-voices/tree/5512791644e2148e4be301d4c7fc2a4bf51a5057
MODEL_HASH="5512791644e2148e4be301d4c7fc2a4bf51a5057"

# Download using wget with timeout and retry
echo "Downloading model (commit: ${MODEL_HASH:0:7})..."
if ! wget -q --timeout=30 --tries=3 \
  -O "$VOICE_DIR/en_GB-southern_english_female-high.onnx" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/${MODEL_HASH}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx"; then
  
  echo "✗ Failed to download voice model (.onnx)" >&2
  rm -f "$VOICE_DIR"/*.tmp 2>/dev/null || true
  exit 1
fi

# Download the model config file  
echo "Downloading model config..."
if ! wget -q --timeout=30 --tries=3 \
  -O "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/${MODEL_HASH}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx.json"; then
  
  echo "✗ Failed to download model config (.json)" >&2
  rm -f "$VOICE_DIR"/*.tmp 2>/dev/null || true
  exit 1
fi

# Verify both files exist
if [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx" ]] || \
   [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" ]]; then
  
  echo "✗ One or more voice files missing after download" >&2
  rm -f "$VOICE_DIR"/*.tmp 2>/dev/null || true
  exit 1
fi

# Verify file size (high quality voice is ~30MB) as secondary validation
ONNX_SIZE=$(stat -c%s "$VOICE_DIR/en_GB-southern_english_female-high.onnx" 2>/dev/null || stat -f%z "$VOICE_DIR/en_GB-southern_english_female-high.onnx")
if (( ONNX_SIZE < 25*1024*1024 )); then
  echo "✗ Voice model file size too small: ${ONNX_SIZE} bytes (expected ~30MB)" >&2
  rm -f "$VOICE_DIR"/*.tmp 2>/dev/null || true
  exit 1
fi

echo "✓ Voice model downloaded successfully"
echo "  Model: en_GB-southern_english_female-high.onnx ($((ONNX_SIZE/1024/1024))MB)"
ls -lh "$VOICE_DIR/"*.onnx "$VOICE_DIR/"*.json

# Ensure proper ownership for hermes user
USERNAME="${2:-$USER}"
HERMES_GROUP="${3:-hermes}"
chown "${USERNAME}:${HERMES_GROUP}" "$VOICE_DIR"/* 2>/dev/null || true
chmod 0640 "$VOICE_DIR"/* 2>/dev/null || true

echo ""
echo "Piper voice ready at: $VOICE_DIR/en_GB-southern_english_female-high.onnx"
echo "Using commit hash: ${MODEL_HASH} (immutable for reproducibility)"
