# Local inference with llama-server

`llama-swap` serves local GGUF models on demand through an OpenAI-compatible HTTP API on TCP port `8080`. Each inference host selects its models from [model-policy.nix](model-policy.nix) by configured GPU memory.

## Inference hosts and VRAM tiers

Hosts with the `inference` tag in [registry-systems.toml](../../../../lib/registry-systems.toml) run `services.llama-swap` and `llama-models-preseed.service`.

| Host | Hardware | Registry VRAM | Acceleration | Policy tier |
|---|---|---:|---|---|
| `skrye` | AMD Ryzen AI Max+ 395 (Strix Halo, 128 GiB unified) | 96 GiB | `vulkan` | `vram64` |
| `zannah` | AMD Ryzen AI Max+ 395 (Strix Halo, 128 GiB unified) | 96 GiB | `vulkan` | `vram64` |
| `maul` | NVIDIA GPU server | 24 GiB | `cuda` | `vram22` |
| `revan` | Intel i9-9900K + NVIDIA RTX 2000e Ada Generation | 16 GiB | `cuda` | `vram16` |

On Strix Halo, `vram = 96` in the registry is the conservative inference budget rather than physical capacity. The `traya` macOS workstation does not carry the `inference` tag, but its Moltis module runs a user `launchd` `llama-swap` agent on `127.0.0.1:8080` that serves `qwen3-embedding-0.6b` only. Other workstations (`bane`, `ravi`, `tanis`, `sidious`) define compute GPU metadata and inherit the matching tier if tagged `inference`.

## Model policy

All inference hosts share [model-policy.nix](model-policy.nix) and [model-downloads.nix](model-downloads.nix).

| Tier | `flint` | `inkling-2-mini` | `qwen3.8-27b` | Small media | Embedding |
|---|---|---|---|---|---|
| `vram64` | `Q8_0`, 256K | `UD-Q4_K_XL`, 256K | `UD-Q4_K_XL`, 256K | `gemma4-e4b`, 128K | `qwen3-embedding-0.6b`, 8K |
| `vram32` | Not served | `UD-Q4_K_XL`, 32K | `UD-Q4_K_XL`, 64K | `gemma4-e4b`, 128K | `qwen3-embedding-0.6b`, 8K |
| `vram22` | Not served | `UD-Q4_K_XL`, 16K | `UD-Q4_K_XL`, 32K | `gemma4-e4b`, 128K | `qwen3-embedding-0.6b`, 8K |
| `vram16` | Not served | `UD-IQ3_XXS`, 16K | `UD-Q3_K_XL`, 16K | `gemma4-e4b`, 128K | `qwen3-embedding-0.6b`, 8K |
| `vram8` | Not served | Not served | Not served | `gemma4-e2b`, 128K | `qwen3-embedding-0.6b`, 8K |

Policy rules that apply across tiers:

- **KV cache quantisation:** every model uses `--cache-type-k q8_0 --cache-type-v q8_0`.
- **Slot allocation:** `flint`, `inkling-2-mini`, and `qwen3.8-27b` run with one slot (`--parallel 1 --no-context-shift`).
- **Strix Halo (`vram64`) tuning:** `inkling-2-mini` sets `--ubatch-size 128`, and `qwen3.8-27b` enables multi-token prediction (MTP) on Vulkan with `--spec-type draft-mtp --spec-draft-n-max 3`. Other tiers do not enable MTP.
- **Pinned snapshots:** `inkling-2-mini` (`unsloth/Inkling-2-Mini-GGUF`, `Mainline_Support/` path) pins revision `45fd08764f2b0bf16b03a5483a80e5c7aaec8772`, and `qwen3.8-27b` (`unsloth/Qwen3.8-27B-GGUF`) pins revision `4af51b3542f775b0a8e4b310bfb3f17e01c306c9`.
- **Small media models:** `gemma4-e4b` and `gemma4-e2b` use `UD-Q6_K_XL` at 131,072 tokens with `mmproj-BF16.gguf` and `--reasoning on`. `UD-Q6_K_XL` meets the Q6_K floor required for reliable Gemma 4 audio beyond about 17 seconds (clips remain capped at 30 seconds by the model).
- **Embeddings:** every tier serves `Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0` at 8,192 tokens with `--embedding --pooling last` and no sampler.

### Generation sampler policy

[model-policy.nix](model-policy.nix) passes each model's sampling flags directly to `llama-server`.

| Model | Temp | Top-p | Top-k | Min-p | Repeat penalty | Extra flags |
|---|---:|---:|---:|---:|---:|---|
| `flint` | `1.0` | `0.95` | `20` | `0.0` | `1.0` | None |
| `inkling-2-mini` | `1.0` | `1.0` | `0` | `0.0` | `1.0` | None |
| `qwen3.8-27b` | `1.0` | `0.95` | `20` | `0.0` | `1.0` | `--presence-penalty 0.0 --reasoning-effort medium` |
| `gemma4-e4b` / `gemma4-e2b` | `1.0` | `0.95` | `64` | `0.0` | `1.0` | `--reasoning on` |

Override `qwen3.8-27b` reasoning effort per request with `reasoning_effort` in the request body.

## November 2026 Strix Halo benchmarks

Both Strix Halo workstations ran the full suite with `llama.cpp` `b12628` and `ollama` from `nixpkgs-unstable`, testing the same local pre-seeded GGUF files (`prompt=4096 tok, output=512 tok, runs=3`, `ctx=8192`, `q8_0` KV cache, shared sampler policy, medians over three measured runs after one warm-up).

### `skrye` (`suite-89sgvx1w`)

| Model | Runner | Backend | Mode | Prefill tok/s | Decode tok/s | TTFT ms | Peak GPU Mem | Status |
|---|---|---|---|---:|---:|---:|---:|---|
| `flint` | `llama.cpp` | `vulkan` | `off` | 1257.1 | 49.0 | 3260 | 46.1 GiB | ok |
| `flint` | `llama.cpp` | `rocm` | `off` | 1282.7 | 44.2 | 3195 | 45.9 GiB | ok |
| `flint` | `ollama` | `vulkan` | `off` | 1203.5 | 48.0 | 3436 | 46.1 GiB | ok |
| `flint` | `ollama` | `rocm` | `off` | 1238.6 | 41.1 | 3320 | 46.2 GiB | ok |
| `inkling-2-mini` | `llama.cpp` | `vulkan` | `off` | 364.4 | 26.6 | 11243 | 23.5 GiB | ok |
| `inkling-2-mini` | `llama.cpp` | `rocm` | `off` | 292.1 | 22.3 | 14027 | 23.0 GiB | ok |
| `inkling-2-mini` | `ollama` | `vulkan` | `off` | - | - | - | - | unsupported: unknown model architecture: `'inkling2_loop'` |
| `inkling-2-mini` | `ollama` | `rocm` | `off` | - | - | - | - | unsupported: unknown model architecture: `'inkling2_loop'` |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `off` | 369.1 | 10.6 | 11101 | 23.5 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `off` | 358.4 | 10.8 | 11431 | 23.1 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp2` | 353.2 | 24.1 | 11599 | 24.2 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `mtp2` | 347.7 | 23.9 | 11782 | 24.5 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp3` | 355.9 | 27.7 | 11511 | 25.6 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `mtp3` | 346.2 | 26.4 | 11835 | 25.9 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp4` | 356.9 | 27.2 | 11479 | 25.7 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp6` | 357.1 | 27.5 | 11472 | 26.3 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp8` | 357.1 | 17.4 | 11472 | 26.5 GiB | ok |
| `qwen3.8-27b` | `ollama` | `vulkan` | `off` | 360.5 | 11.6 | 11425 | 24.8 GiB | ok |
| `qwen3.8-27b` | `ollama` | `rocm` | `off` | 377.6 | 11.6 | 10873 | 24.1 GiB | ok |
| `gemma4-e4b` | `llama.cpp` | `vulkan` | `off` | 3119.7 | 41.5 | 1315 | 15.2 GiB | ok |
| `gemma4-e4b` | `llama.cpp` | `rocm` | `off` | 2483.2 | 38.0 | 1651 | 11.8 GiB | ok |
| `gemma4-e4b` | `ollama` | `vulkan` | `off` | 2982.4 | 40.8 | 1472 | 15.1 GiB | ok |
| `gemma4-e4b` | `ollama` | `rocm` | `off` | 2439.5 | 36.1 | 1772 | 12.0 GiB | ok |

### `zannah` (`suite-es116ulj`)

| Model | Runner | Backend | Mode | Prefill tok/s | Decode tok/s | TTFT ms | Peak GPU Mem | Status |
|---|---|---|---|---:|---:|---:|---:|---|
| `flint` | `llama.cpp` | `vulkan` | `off` | 1330.9 | 52.5 | 3080 | 40.7 GiB | ok |
| `flint` | `llama.cpp` | `rocm` | `off` | 1369.0 | 47.1 | 2993 | 40.5 GiB | ok |
| `flint` | `ollama` | `vulkan` | `off` | 1285.1 | 51.8 | 3219 | 40.6 GiB | ok |
| `flint` | `ollama` | `rocm` | `off` | 1333.8 | 42.5 | 3089 | 40.5 GiB | ok |
| `inkling-2-mini` | `llama.cpp` | `vulkan` | `off` | 355.7 | 26.5 | 11519 | 17.9 GiB | ok |
| `inkling-2-mini` | `llama.cpp` | `rocm` | `off` | 290.5 | 22.4 | 14100 | 17.6 GiB | ok |
| `inkling-2-mini` | `ollama` | `vulkan` | `off` | - | - | - | - | unsupported: unknown model architecture: `'inkling2_loop'` |
| `inkling-2-mini` | `ollama` | `rocm` | `off` | - | - | - | - | unsupported: unknown model architecture: `'inkling2_loop'` |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `off` | 385.8 | 11.9 | 10620 | 17.9 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `off` | 370.0 | 11.8 | 11072 | 17.5 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp2` | 362.8 | 25.8 | 11293 | 18.8 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `mtp2` | 358.4 | 25.5 | 11431 | 18.8 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp3` | 366.0 | 29.4 | 11194 | 18.9 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `rocm` | `mtp3` | 355.8 | 28.6 | 11516 | 19.0 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp4` | 370.2 | 28.8 | 11067 | 19.1 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp6` | 360.4 | 29.0 | 11369 | 19.4 GiB | ok |
| `qwen3.8-27b` | `llama.cpp` | `vulkan` | `mtp8` | 368.6 | 18.3 | 11117 | 19.7 GiB | ok |
| `qwen3.8-27b` | `ollama` | `vulkan` | `off` | 374.8 | 12.0 | 10969 | 17.7 GiB | ok |
| `qwen3.8-27b` | `ollama` | `rocm` | `off` | 368.4 | 11.4 | 11148 | 17.5 GiB | ok |
| `gemma4-e4b` | `llama.cpp` | `vulkan` | `off` | 2905.4 | 40.4 | 1413 | 8.8 GiB | ok |
| `gemma4-e4b` | `llama.cpp` | `rocm` | `off` | 2418.2 | 38.0 | 1697 | 5.6 GiB | ok |
| `gemma4-e4b` | `ollama` | `vulkan` | `off` | 2877.0 | 39.9 | 1523 | 8.8 GiB | ok |
| `gemma4-e4b` | `ollama` | `rocm` | `off` | 2404.6 | 36.0 | 1802 | 5.6 GiB | ok |

### Key conclusions

- **Vulkan beats ROCm for production serving:** on `llama.cpp`, Vulkan leads ROCm decode by 10.9% to 11.5% on `flint`, 18.3% to 19.3% on `inkling-2-mini`, and 6.3% to 9.2% on `gemma4-e4b`. Vulkan also speeds up prefill by 22.4% to 24.8% on `inkling-2-mini` and 20.1% to 25.6% on `gemma4-e4b`. On `qwen3.8-27b`, both backends hit the LPDDR5X memory bandwidth ceiling at `mode=off`, and Vulkan stays 2.8% to 4.9% ahead at `mtp3`. ROCm edges Vulkan by 2% to 3% on `flint` prefill and uses 3.2 to 3.4 GiB less GPU memory on `gemma4-e4b`, which does not outweigh Vulkan's decode lead.
- **`qwen3.8-27b` peaks at `mtp3`:** multi-token prediction lifts Vulkan decode from 10.6 to 27.7 tok/s on `skrye` (2.6x) and from 11.9 to 29.4 tok/s on `zannah` (2.5x). Draft limits of `mtp4` and `mtp6` plateau just below `mtp3` while using more memory, and `mtp8` drops decode by 37% (`17.4` tok/s on `skrye`, `18.3` tok/s on `zannah`). Production policy therefore pins `mtpDraftTokens = 3` on `vram64` Vulkan hosts.
- **`llama.cpp` stays ahead of Ollama:** setting `OLLAMA_IGPU_ENABLE=1` on Vulkan closes Ollama's `mode=off` decode gap to 1% to 2% on `flint` and `gemma4-e4b` and places it slightly ahead of `llama.cpp` `mode=off` on `qwen3.8-27b`. Production still requires `llama.cpp` for three reasons: `qwen3.8-27b` with `mtp3` runs 2.4x faster than Ollama (`27.7` to `29.4` tok/s versus `11.6` to `12.0` tok/s), Ollama rejects `inkling-2-mini` with `unknown model architecture: 'inkling2_loop'`, and `llama.cpp` serves Gemma 4 `UD-Q6_K_XL` with `mmproj-BF16.gguf` for reliable vision and audio input.
- **Hardware variance and desktop GPU baseline:** `zannah` runs roughly 5% to 7% faster than `skrye` on `flint` and `qwen3.8-27b`. Across every case, `skrye` records 5.4 to 6.4 GiB higher `Peak GPU Mem` than `zannah` because of its active dual-display desktop GPU baseline (two 2560x2880 displays), not higher model allocation.

## Benchmarking with `benchmark-models`

Linux inference hosts install `benchmark-models` and `benchmark-models-all` from [home-manager/_mixins/scripts/benchmark-models/default.nix](../../../../home-manager/_mixins/scripts/benchmark-models/default.nix).

```bash
benchmark-models-all [--llama-only|--ollama-only] [--json] [--runs N]
benchmark-models [--llama-only|--ollama-only] [--json] MODEL [runs]
benchmark-models --purge
```

- `benchmark-models-all` benchmarks all generation models configured for the host's VRAM tier (`flint`, `inkling-2-mini`, `qwen3.8-27b`, and `gemma4-e4b` or `gemma4-e2b`) and defaults to `--runs 3`.
- `benchmark-models` benchmarks one model. `flint`, `inkling-2-mini`, and `qwen3.8-27b` run the shared Python harness (`focused.py`, default 3 runs). Single-model `gemma4-e2b`, `gemma4-e4b`, and opt-in `qwen3-embedding-0.6b` use the shell runner (default 5 runs).
- `benchmark-models --purge` removes `~/Volatile/benchmark-models` without touching `/var/lib/llama-models/huggingface`.
- Set `BENCHMARK_MODELS_ROOT` to move caches and logs (default `~/Volatile/benchmark-models`) or `BENCHMARK_MODELS_OLLAMA_HOST` for the shell runner's temporary Ollama port (default `127.0.0.1:11435`).

### Suite methodology

The Python suite in `focused.py` enforces parity between `llama.cpp` and Ollama:

- **Shared weights and settings:** both engines load the exact same GGUF file from `/var/lib/llama-models/huggingface` (falling back to `hf download` into `~/Volatile/benchmark-models/huggingface` if missing) with `ctx=8192`, `q8_0` KV cache, `seed=42`, single slot, aligned micro-batch size, and the sampler policy from [model-policy.nix](model-policy.nix).
- **Calibrated 4,096-token prompts:** `llama-server` tokenises an exact 4,096-token prompt and generates 512 output tokens. Ollama calibrates line counts to match 4,096 prompt tokens within tolerance (`±32` during calibration, maximum drift `256`).
- **No prefix cache reuse:** `llama-server` disables prompt caching (`--no-cache-prompt --cache-ram 0`). Ollama prepends a unique per-sample nonce to every request so slot prefix KV caching cannot reuse prefill state across probes, warm-up, or timed runs.
- **Vulkan iGPU enablement:** Ollama receives `OLLAMA_VULKAN=1` and `OLLAMA_IGPU_ENABLE=1` on Vulkan so it does not drop AMD integrated GPUs.
- **Unified GPU memory reporting:** on AMD hosts, a 200 ms sampler sums `mem_info_vram_used + mem_info_gtt_used` from `amdgpu` sysfs and reports both `Peak GPU Mem` and `Delta GPU Mem` (`peak - pre-load baseline`).
- **Default MTP matrix:** for models with `mtpDraftTokens` configured (`qwen3.8-27b` on `vram64`), the default sweep tests Vulkan `off`, `mtp2`, `mtp3`, and `mtp4`, plus ROCm `off`, `mtp2`, and `mtp3`. `mtp6` and `mtp8` are omitted from the default sweep because the November 2026 runs confirmed `mtp3` is the peak and `mtp8` drops 37%.

Results, per-case JSONL streams, logs, and `summary.json` save under `~/Volatile/benchmark-models/suite-*` (or `<model>-*`).

## NixOS infrastructure

### Packages and service layout

- **Package pins ([overlays/default.nix](../../../../overlays/default.nix)):** `pkgs.llama-swap` and `pkgs.huggingface-cli` track `nixpkgs-unstable`. On Linux, `pkgs.llama-cpp` pins upstream `b12628` (`8a97fa9`) until `nixpkgs-unstable` includes Inkling model support. Darwin uses the cached `nixpkgs-unstable` package.
- **`llama-swap` service ([swap.nix](swap.nix)):** listens on port `8080`, allocates backend ports from `10001`, sets `globalTTL = 0` and `healthCheckTimeout = 500`, and builds `pkgs.llama-cpp` with `vulkanSupport`, `cudaSupport`, or `rocmSupport` from `host.gpu.compute.acceleration`.
- **Process groups:** `embedding` sets `exclusive = false` and `swap = false` so `qwen3-embedding-0.6b` stays resident. `generation` sets `exclusive = false` and `swap = true` so generation models load on demand and replace each other without unloading embeddings.
- **Accelerator flags ([runtime.nix](runtime.nix)):** Vulkan hosts add `--flash-attn on --load-mode none` (plus `--spec-type draft-mtp --spec-draft-n-max 3` on `vram64` `qwen3.8-27b`), expose `/run/opengl-driver` libraries and ICD data, and run in the `render` and `video` groups. CUDA hosts (`maul`, `revan`) omit `--load-mode none`.
- **Pre-seeding ([preseed.nix](preseed.nix)):** `llama-models-preseed.service` runs before `llama-swap.service`, downloads the host's selected files via `hf download` into `/var/lib/llama-models/huggingface`, and prunes retired repositories (`LLAMA_PRESEED_PRUNE=1`) only after every selected file passes verification.

### Strix Halo host configuration

Both `skrye` and `zannah` import `nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series` and expand the GTT pool to ~120 GiB in [nixos/skrye/default.nix](../../../skrye/default.nix) and [nixos/zannah/default.nix](../../../zannah/default.nix):

```nix
boot.extraModprobeConfig = ''
  # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
  options ttm pages_limit=31457280
'';
```

- Use `ttm.pages_limit` only, because `amdgpu.gttsize` is deprecated.
- Set BIOS `UMA Frame Buffer Size` to `512 MB` (`Advanced -> AMD CBS -> NBIO -> GFX Configuration`) so the OS keeps system RAM and TTM claims GPU memory dynamically.
- Leave GPU clock management on `auto` DPM and omit IOMMU kernel parameters. The iGPU boosts automatically under load without overrides.
- Monitor Strix Halo clocks, power, and memory with `amdgpu_top`.

## Client routing and monitoring

Active services in this repository consume `llama-swap` directly over localhost or Tailscale:

| Service | Host | Endpoint | Models used |
|---|---|---|---|
| LibreChat | `revan` | `http://skrye.<tailnet>:8080/v1`, `http://zannah.<tailnet>:8080/v1` | `flint`, `inkling-2-mini`, `qwen3.8-27b` (`inkling-2-mini` for conversation titles) |
| Silo | `revan` | `http://127.0.0.1:8080/v1` | `qwen3-embedding-0.6b` (media recommendations) |
| Moltis | `skrye`, `zannah`, `traya` | `http://127.0.0.1:8080/v1` | `qwen3-embedding-0.6b` (agent memory) |
| Gatus and Homepage | `revan` | `http://127.0.0.1:8080/health`, `/running`, Tailscale `8080` links | Health and loaded-model monitoring across `revan`, `skrye`, and `zannah` |

For the GPU trade-off analysis on `revan` between its current 16 GB RTX 2000e Ada (`vram16`) and a 22 GB modded RTX 2080 Ti (`vram22`), see [RTX-2000e-Ada Generation-vs-2080Ti-22GB.md](RTX-2000e-Ada%20Generation-vs-2080Ti-22GB.md).
