#!/usr/bin/env bash

for model in \
  gemma4:26b \
  gemma4:31b \
  gemma4:e2b \
  gemma4:e4b \
  gpt-oss:20b \
  qwen3:1.7b \
  qwen3-coder-next \
  qwen3.5:9b \
  qwen3.5:27b \
  qwen3.5:35b-a3b; do
	benchmark-models "${model}" | tee -a ~/benchmark-models.txt
done
