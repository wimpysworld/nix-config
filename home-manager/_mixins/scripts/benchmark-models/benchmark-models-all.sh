#!/usr/bin/env bash

for model in \
  gemma4:26b \
  gemma4:31b \
  gemma4:e2b \
  gemma4:e4b \
  gpt-oss:20b \
  qwen2.5-coder:7b \
  qwen2.5-coder:14b \
  qwen3:1.7b \
  qwen3-coder:30b \
  qwen3-coder-next \
  qwen3.5:9b \
  qwen3.6:27b \
  qwen3.6:35b \
  rnj-1:8b; do
    benchmark-models "${model}"
done
