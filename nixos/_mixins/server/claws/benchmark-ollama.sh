#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-qwen3.5:27b}"
RUNS="${2:-5}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

PAYLOAD=$(printf '{
  "model": "%s",
  "prompt": "Write a detailed 500-word essay about the history of optical fibre telecommunications.",
  "stream": false,
  "options": { "num_predict": 512, "temperature": 0.0 },
  "think": false
}' "$MODEL")

run_once() {
  curl -s "${HOST}/api/generate" \
    -d "$PAYLOAD" \
    | jq -r '(.eval_count / (.eval_duration / 1000000000))' >> "$TMPFILE"
}
export -f run_once
export PAYLOAD TMPFILE HOST

# --- Map Ollama model names to HuggingFace repo:quant for llama-bench ---
LLAMA_TPS=""
LLAMA_SKIPPED=""
# shellcheck disable=SC2034 # read in conditional branches below; shellcheck cannot trace it
VULKAN_TPS=""
# shellcheck disable=SC2034 # read in conditional branches below; shellcheck cannot trace it
VULKAN_SKIPPED=""
HF_REPO=""

hf_repo_for_model() {
  case "$1" in
    qwen3.5:4b)               echo "unsloth/Qwen3.5-4B-GGUF:Q4_K_M" ;;
    qwen3.5:9b)               echo "unsloth/Qwen3.5-9B-GGUF:Q4_K_M" ;;
    qwen3.5:27b)              echo "unsloth/Qwen3.5-27B-GGUF:Q4_K_M" ;;
    qwen3.5:35b-a3b)          echo "unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M" ;;
    gemma4:e4b)               echo "unsloth/gemma-4-E4B-it-GGUF:Q4_K_M" ;;
    gemma4:26b | gemma4:26b:latest) echo "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_M" ;;
    gemma4:31b | gemma4:31b:latest) echo "unsloth/gemma-4-31B-it-GGUF:Q4_K_M" ;;
    qwen3-embedding:4b-q8_0)  echo "Qwen/Qwen3-Embedding-4B-GGUF:Q8_0" ;;
    qwen3-coder-next | qwen3-coder-next:latest) echo "unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M" ;;
    *)                        echo "" ;;
  esac
}

if ! command -v llama-bench &>/dev/null; then
  LLAMA_SKIPPED="llama-bench not found in PATH; skipping llama-bench."
else
  HF_REPO=$(hf_repo_for_model "$MODEL")
  if [[ -z "$HF_REPO" ]]; then
    LLAMA_SKIPPED="No HF mapping for ${MODEL}; skipping llama-bench."
  fi
fi

# --- Ollama benchmark ---
if ! ollama show "$MODEL" > /dev/null 2>&1; then
  printf "Pulling %s from Ollama...\n\n" "$MODEL"
  ollama pull "$MODEL"
  printf "\n"
fi

printf "=== Ollama Benchmark: %s ===\n" "$MODEL"
printf "    Host: %s\n" "$HOST"
printf "    Runs: %s (+ 1 warmup)\n" "$RUNS"
printf "\n"

hyperfine --runs "$RUNS" --warmup 1 --shell bash 'run_once'

printf "\n"
printf "=== Token Generation Speed ===\n"
awk '{
  sum += $1
  if (NR == 1 || $1 < min) min = $1
  if (NR == 1 || $1 > max) max = $1
}
END {
  mean = sum / NR
  printf "  Mean:   %6.2f tok/s\n", mean
  printf "  Min:    %6.2f tok/s\n", min
  printf "  Max:    %6.2f tok/s\n", max
  printf "  Spread: %6.2f tok/s\n", max - min
}' "$TMPFILE"
OLLAMA_MEAN=$(awk '{ sum += $1 } END { printf "%f", sum / NR }' "$TMPFILE")
printf "\n"

# --- llama-bench section ---
if [[ -z "$LLAMA_SKIPPED" ]] && [[ -n "$HF_REPO" ]]; then
  printf "=== llama-bench: %s ===\n" "$MODEL"
  printf "    HF repo: %s\n" "$HF_REPO"
  printf "    Note: first run will download the model\n"
  printf "    Runs: %s\n" "$RUNS"
  printf "\n"

  LLAMA_OUTPUT=""
  if ! LLAMA_OUTPUT=$(llama-bench -hf "$HF_REPO" -ngl 99 -fa 1 -p 0 -n 512 -r "$RUNS" -o json 2>/dev/null); then
    LLAMA_SKIPPED="llama-bench exited with an error."
  elif ! echo "$LLAMA_OUTPUT" | jq empty 2>/dev/null; then
    LLAMA_SKIPPED="llama-bench produced invalid JSON output."
  else
    LLAMA_TPS=$(echo "$LLAMA_OUTPUT" | jq -r '[.[] | select(.n_gen > 0)] | .[0].avg_ts // empty')
  fi

  if [[ -n "$LLAMA_TPS" ]]; then
    printf "  Mean:   %6.2f tok/s  (over %s runs)\n" "$LLAMA_TPS" "$RUNS"
  elif [[ -z "$LLAMA_SKIPPED" ]]; then
    LLAMA_SKIPPED="llama-bench produced no usable tg results."
  fi
  printf "\n"
fi

# --- Vulkan llama-bench section ---
if ! command -v vulkan-llama-bench &>/dev/null; then
  VULKAN_SKIPPED="vulkan-llama-bench not found"
elif [[ -z "$HF_REPO" ]]; then
  VULKAN_SKIPPED="No HF mapping for ${MODEL}; skipping vulkan-llama-bench."
fi

if [[ -z "$VULKAN_SKIPPED" ]] && [[ -n "$HF_REPO" ]]; then
  printf "=== vulkan-llama-bench: %s ===\n" "$MODEL"
  printf "    HF repo: %s\n" "$HF_REPO"
  printf "    Runs: %s\n" "$RUNS"
  printf "\n"

  VULKAN_OUTPUT=""
  if ! VULKAN_OUTPUT=$(vulkan-llama-bench -hf "$HF_REPO" -ngl 99 -fa 1 -p 0 -n 512 -r "$RUNS" -o json 2>/dev/null); then
    VULKAN_SKIPPED="vulkan-llama-bench exited with an error."
  elif ! echo "$VULKAN_OUTPUT" | jq empty 2>/dev/null; then
    VULKAN_SKIPPED="vulkan-llama-bench produced invalid JSON output."
  else
    VULKAN_TPS=$(echo "$VULKAN_OUTPUT" | jq -r '[.[] | select(.n_gen > 0)] | .[0].avg_ts // empty')
  fi

  if [[ -n "$VULKAN_TPS" ]]; then
    printf "  Mean:   %6.2f tok/s  (over %s runs)\n" "$VULKAN_TPS" "$RUNS"
  elif [[ -z "$VULKAN_SKIPPED" ]]; then
    VULKAN_SKIPPED="vulkan-llama-bench produced no usable tg results."
  fi
  printf "\n"
fi

# --- Comparison ---
printf "=== Comparison: %s ===\n" "$MODEL"
printf "  Ollama:                %6.2f tok/s  (mean over %s runs)\n" "$OLLAMA_MEAN" "$RUNS"

if [[ -n "$LLAMA_SKIPPED" ]]; then
  printf "  llama-bench:           [skipped: %s]\n" "$LLAMA_SKIPPED"
else
  printf "  llama-bench:           %6.2f tok/s  (mean over %s runs)\n" "$LLAMA_TPS" "$RUNS"
fi

if [[ -n "$VULKAN_SKIPPED" ]]; then
  printf "  vulkan-llama-bench:    [skipped: %s]\n" "$VULKAN_SKIPPED"
else
  printf "  vulkan-llama-bench:    %6.2f tok/s  (mean over %s runs)\n" "$VULKAN_TPS" "$RUNS"
fi

printf "\n"

# Delta: Ollama vs llama-bench
if [[ -n "$LLAMA_TPS" && -n "$OLLAMA_MEAN" ]]; then
  DELTA_LLAMA=$(awk "BEGIN { printf \"%.2f\", ${LLAMA_TPS} - ${OLLAMA_MEAN} }")
  if awk "BEGIN { exit (${LLAMA_TPS} >= ${OLLAMA_MEAN}) ? 1 : 0 }"; then
    DIR_LLAMA="Ollama faster"
  else
    DIR_LLAMA="llama-bench faster"
  fi
  printf "  Ollama vs llama-bench:         %+6.2f tok/s  (%s)\n" "$DELTA_LLAMA" "$DIR_LLAMA"
fi

# Delta: Ollama vs vulkan-llama-bench
if [[ -n "$VULKAN_TPS" && -n "$OLLAMA_MEAN" ]]; then
  DELTA_VULKAN=$(awk "BEGIN { printf \"%.2f\", ${VULKAN_TPS} - ${OLLAMA_MEAN} }")
  if awk "BEGIN { exit (${VULKAN_TPS} >= ${OLLAMA_MEAN}) ? 1 : 0 }"; then
    DIR_VULKAN="Ollama faster"
  else
    DIR_VULKAN="vulkan-llama-bench faster"
  fi
  printf "  Ollama vs vulkan-llama-bench:  %+6.2f tok/s  (%s)\n" "$DELTA_VULKAN" "$DIR_VULKAN"
fi

# Delta: llama-bench vs vulkan-llama-bench
if [[ -n "$LLAMA_TPS" && -n "$VULKAN_TPS" ]]; then
  DELTA_RV=$(awk "BEGIN { printf \"%.2f\", ${VULKAN_TPS} - ${LLAMA_TPS} }")
  if awk "BEGIN { exit (${VULKAN_TPS} >= ${LLAMA_TPS}) ? 1 : 0 }"; then
    DIR_RV="llama-bench faster"
  else
    DIR_RV="vulkan-llama-bench faster"
  fi
  printf "  llama-bench vs vulkan-llama-bench: %+6.2f tok/s  (%s)\n" "$DELTA_RV" "$DIR_RV"
fi

printf "\n"
