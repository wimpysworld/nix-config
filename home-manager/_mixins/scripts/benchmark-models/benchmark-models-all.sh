#!/usr/bin/env bash

for model in \
  gemma4:26b \
  gemma4:e4b \
  gpt-oss:20b \
  qwen3.5:9b \
  qwen3.6:27b \
  qwen3.6-mtp:27b \
  qwen3.6:35b \
  qwen3.6-mtp:35b; do
    benchmark-models "${model}"
done
