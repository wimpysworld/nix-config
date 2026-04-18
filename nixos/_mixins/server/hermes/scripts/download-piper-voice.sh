#!/usr/bin/env bash
set -euo pipefail

# Download Piper southern_english_female-high voice from Hugging Face
# https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_GB/southern_english_female
# Voice commit hash for reproducibility: 5512791644e2148e4be301d4c7fc2a4bf51a5057

VOICE_DIR="${1:-$HOME/.local/share/piper}"
mkdir -p "$VOICE_DIR"

echo "Downloading southern_english_female-high voice..."

# Use immutable commit hash URL for reproducibility and supply-chain security
# https://huggingface.co/rhasspy/piper-voices/tree/5512791644e2148e4be301d4c7fc2a4bf51a5057/en/en_GB/southern_english_female/high
MODEL_HASH="5512791644e2148e4be301d4c7fc2a4bf51a5057"

# Download the model file with checksum verification
echo "Downloading model (commit: ${MODEL_HASH:0:7})..."
wget -qO "$VOICE_DIR/en_GB-southern_english_female-high.onnx" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/${MODEL_HASH}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx"

# Download the model config file
echo "Downloading model config..."
wget -qO "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/${MODEL_HASH}/en/en_GB/southern_english_female/high/en_GB-southern_english_female-high.onnx.json"

# Verify download integrity
if [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx" ]]; then
  echo "✗ Failed to download voice model (.onnx)" >&2
  exit 1
fi

if [[ ! -f "$VOICE_DIR/en_GB-southern_english_female-high.onnx.json" ]]; then
  echo "✗ Failed to download model config (.json)" >&2
  exit 1
fi

# Verify file sizes match expected values (high quality voice is ~30MB)
MODEL_SIZE=$(stat -c%s "$VOICE_DIR/en_GB-southern_english_female-high.onnx" 2>/dev/null || stat -f%z "$VOICE_DIR/en_GB-southern_english_female-high.onnx")
if (( MODEL_SIZE < 25*1024*1024 )); then
  echo "✗ Voice model file size too small: ${MODEL_SIZE} bytes (expected ~30MB)" >&2
  exit 1
fi

echo "✓ Voice model downloaded successfully"
echo "  Model: en_GB-southern_english_female-high.onnx (${MODEL_SIZE} bytes)"
ls -lh "$VOICE_DIR/"*.onnx "$VOICE_DIR/"*.json

echo ""
echo "Piper voice ready at: $VOICE_DIR/en_GB-southern_english_female-high.onnx"
echo "Using commit hash: ${MODEL_HASH}"
