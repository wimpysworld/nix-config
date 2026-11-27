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

On Strix Halo, `vram = 96` in the registry is the conservative inference budget rather than physical capacity. The `traya` macOS workstation does not carry the `inference` tag, but its Moltis module runs a user `launchd` `llama-swap` agent on `127.0.0.1:8080` that serves `qwen3-embedding-0.6b` only. Other workstations (`bane`, `ravi`) define compute GPU metadata and inherit the matching tier if tagged `inference`. Active `inference` hosts require at least 16 GiB of configured compute VRAM.

## Model policy

All inference hosts share [model-policy.nix](model-policy.nix) and [model-downloads.nix](model-downloads.nix).

| Tier | moe | dense (vision) | embedding (qwen3-embedding-0.6b) |
| --- | --- | --- | --- |
| `vram64` (`skrye`, `zannah`) | `inkling-2-mini` (vision), `UD-Q4_K_XL`, 256K, `ubatch 128` (~23.3 GiB) | `qwen3.8-27b`, `UD-Q4_K_XL`, 256K, `mtp 3`, `reasoning medium` (~28.8 GiB) | `Q8_0`, 8K (~0.9 GiB) |
| `vram32` (`bane`, `ravi`, `traya`) | `inkling-2-mini` (vision), `UD-Q4_K_XL`, 256K, `ubatch 128` (~23.3 GiB) | `qwen3.8-27b`, `UD-Q4_K_XL`, 256K, `mtp 3`, `reasoning medium` (~28.8 GiB) | `Q8_0`, 8K (~0.9 GiB) |
| `vram22` (`maul`) | `mellum2.1-12b` (text-only), `Q8_0`, 128K (~14.9 GiB) | `qwen3.5-9b`, `UD-Q4_K_XL`, 256K, `reasoning off` (~12.8 GiB) | `Q8_0`, 8K (~0.9 GiB) |
| `vram16` (`revan`) | `mellum2.1-12b` (text-only), `Q6_K`, 128K (~13.0 GiB) | `qwen3.5-9b`, `UD-Q4_K_XL`, 128K, `reasoning off` (~10.7 GiB) | `Q8_0`, 8K (~0.9 GiB) |

Policy rules that apply across tiers:

- **Quantisation and context floor:** every generation model runs with at least 128K context and `q8_0` KV cache. `inkling-2-mini`, `qwen3.8-27b`, and `qwen3.5-9b` use `UD-Q4_K_XL`. `mellum2.1-12b` (`JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF`, Apache 2.0, 12B total and 2.5B active MoE) uses `Q8_0` (12.04 GiB) on `vram22` and `Q6_K` (10.13 GiB) on `vram16`. Its 128K (`131072`) context is its native 16x layer-selective YaRN ceiling (7 full-attention GQA layers and 21 sliding-window 1,024 layers). Do not push it to 256K.
- **Vision and text-only models:** `inkling-2-mini`, `qwen3.8-27b`, and `qwen3.5-9b` download and load `mmproj-BF16.gguf` on GPU. `mellum2.1-12b` is text-only and loads no vision projector.
- **Slot allocation and tuning:** `inkling-2-mini` runs with `--parallel 1 --no-context-shift --ubatch-size 128` on `vram64` and `vram32`. `mellum2.1-12b` runs with `--parallel 1 --no-context-shift` and no MTP speculative decoding (JetBrains measured 1.00x to 1.10x at `n_max=1` and slowdowns at `>=2`). `qwen3.8-27b` runs with `--parallel 1 --no-context-shift` and enables `--spec-type draft-mtp --spec-draft-n-max 3` on Vulkan (`vram64` and `vram32`). `qwen3.5-9b` (`unsloth/Qwen3.5-9B-MTP-GGUF`) keeps multi-slot unified KV and `--reasoning off` in production so LibreChat titles, activity labels, and memory extraction run concurrently.
- **Pinned snapshots:** `inkling-2-mini` (`unsloth/Inkling-2-Mini-GGUF`, `Mainline_Support/` path) pins revision `45fd08764f2b0bf16b03a5483a80e5c7aaec8772`, and `qwen3.8-27b` (`unsloth/Qwen3.8-27B-GGUF`) pins revision `4af51b3542f775b0a8e4b310bfb3f17e01c306c9`.
- **Embeddings:** every tier serves `Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0` at 8,192 tokens with `--embedding --pooling last` and no sampler.

### Generation sampler policy

[model-policy.nix](model-policy.nix) passes each model's sampling flags directly to `llama-server`.

| Model | Temp | Top-p | Top-k | Min-p | Repeat penalty | Extra flags |
|---|---:|---:|---:|---:|---:|---|
| `inkling-2-mini` | `1.0` | `1.0` | `0` | `0.0` | `1.0` | None |
| `mellum2.1-12b` | `0.6` | `0.95` | `20` | `0.0` | `1.0` | None |
| `qwen3.8-27b` | `1.0` | `0.95` | `20` | `0.0` | `1.0` | `--presence-penalty 0.0 --reasoning-effort medium` |
| `qwen3.5-9b` | `0.7` | `0.8` | `20` | `0.0` | `1.0` | `--presence-penalty 1.5 --reasoning off` |

Override `qwen3.8-27b` reasoning effort per request with `reasoning_effort` in the request body.

## November 2026 Strix Halo benchmarks

Both Strix Halo workstations ran the full suite with `llama.cpp` `b12628` and `ollama` from `nixpkgs-unstable`, testing the same local pre-seeded GGUF files (`prompt=4096 tok, output=512 tok, runs=3`, `ctx=8192`, `q8_0` KV cache, shared sampler policy, medians over three measured runs after one warm-up).

### `skrye` (`suite-89sgvx1w`)

| Model | Runner | Backend | Mode | Prefill tok/s | Decode tok/s | TTFT ms | Peak GPU Mem | Status |
|---|---|---|---|---:|---:|---:|---:|---|
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

### `zannah` (`suite-es116ulj`)

| Model | Runner | Backend | Mode | Prefill tok/s | Decode tok/s | TTFT ms | Peak GPU Mem | Status |
|---|---|---|---|---:|---:|---:|---:|---|
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

### Key conclusions

- **Vulkan beats ROCm for production serving:** on `llama.cpp`, Vulkan leads ROCm decode by 18.3% to 19.3% on `inkling-2-mini` and speeds up prefill by 22.4% to 24.8%. On `qwen3.8-27b`, both backends hit the LPDDR5X memory bandwidth ceiling at `mode=off`, and Vulkan stays 2.8% to 4.9% ahead at `mtp3`.
- **`qwen3.8-27b` peaks at `mtp3`:** multi-token prediction lifts Vulkan decode from 10.6 to 27.7 tok/s on `skrye` (2.6x) and from 11.9 to 29.4 tok/s on `zannah` (2.5x). Draft limits of `mtp4` and `mtp6` plateau just below `mtp3` while using more memory, and `mtp8` drops decode by 37% (`17.4` tok/s on `skrye`, `18.3` tok/s on `zannah`). Production policy therefore pins `mtpDraftTokens = 3` on `vram64` Vulkan hosts.
- **`llama.cpp` stays ahead of Ollama:** setting `OLLAMA_IGPU_ENABLE=1` on Vulkan places Ollama slightly ahead of `llama.cpp` `mode=off` on `qwen3.8-27b`, but production requires `llama.cpp` because `qwen3.8-27b` with `mtp3` runs 2.4x faster than Ollama (`27.7` to `29.4` tok/s versus `11.6` to `12.0` tok/s), Ollama rejects `inkling-2-mini` with `unknown model architecture: 'inkling2_loop'`, and `llama.cpp` serves `mmproj-BF16.gguf` vision projectors directly for `inkling-2-mini`, `qwen3.8-27b`, and `qwen3.5-9b`.
- **Hardware variance and desktop GPU baseline:** `zannah` runs roughly 5% to 7% faster than `skrye` on `qwen3.8-27b`. Across every case, `skrye` records 5.4 to 6.4 GiB higher `Peak GPU Mem` than `zannah` because of its active dual-display desktop GPU baseline (two 2560x2880 displays), not higher model allocation.

## Benchmarking with `benchmark-models`

Linux inference hosts install `benchmark-models` and `benchmark-models-all` from [home-manager/_mixins/scripts/benchmark-models/default.nix](../../../../home-manager/_mixins/scripts/benchmark-models/default.nix).

```bash
benchmark-models-all [--llama-only|--ollama-only] [--json] [--runs N]
benchmark-models [--llama-only|--ollama-only] [--json] MODEL [runs]
benchmark-models --purge
```

- `benchmark-models-all` benchmarks all generation models configured for the host's VRAM tier plus `qwen3.5-9b` (`inkling-2-mini`, `qwen3.8-27b`, and `qwen3.5-9b` on `vram64` and `vram32`, or `mellum2.1-12b` and `qwen3.5-9b` on `vram22` and `vram16`) and defaults to `--runs 3`.
- `benchmark-models` benchmarks one model. `inkling-2-mini`, `mellum2.1-12b`, `qwen3.5-9b`, and `qwen3.8-27b` run the shared Python harness (`focused.py`, default 3 runs). Opt-in `qwen3-embedding-0.6b` uses the shell runner (default 5 runs).
- `benchmark-models --purge` removes `~/Volatile/benchmark-models` without touching `/var/lib/llama-models/huggingface`.
- Set `BENCHMARK_MODELS_ROOT` to move caches and logs (default `~/Volatile/benchmark-models`) or `BENCHMARK_MODELS_OLLAMA_HOST` for the shell runner's temporary Ollama port (default `127.0.0.1:11435`).

### Suite methodology

The Python suite in `focused.py` enforces parity between `llama.cpp` and Ollama:

- **Shared weights and settings:** both engines load the exact same GGUF file from `/var/lib/llama-models/huggingface` (falling back to `hf download` into `~/Volatile/benchmark-models/huggingface` if missing) with `ctx=8192`, `q8_0` KV cache, `seed=42`, single slot, aligned micro-batch size, and the sampler policy from [model-policy.nix](model-policy.nix).
- **Calibrated 4,096-token prompts:** `llama-server` tokenises an exact 4,096-token prompt and generates 512 output tokens. Ollama calibrates line counts to match 4,096 prompt tokens within tolerance (`±32` during calibration, maximum drift `256`).
- **No prefix cache reuse:** `llama-server` disables prompt caching (`--no-cache-prompt --cache-ram 0`). Ollama prepends a unique per-sample nonce to every request so slot prefix KV caching cannot reuse prefill state across probes, warm-up, or timed runs.
- **Vulkan iGPU enablement:** Ollama receives `OLLAMA_VULKAN=1` and `OLLAMA_IGPU_ENABLE=1` on Vulkan so it does not drop AMD integrated GPUs.
- **Unified GPU memory reporting:** on AMD hosts, a 200 ms sampler sums `mem_info_vram_used + mem_info_gtt_used` from `amdgpu` sysfs and reports both `Peak GPU Mem` and `Delta GPU Mem` (`peak - pre-load baseline`).
- **Default MTP matrix:** for models whose GGUF carries MTP tensors (`qwen3.8-27b` and `qwen3.5-9b`), the default sweep tests `off`, `mtp2`, `mtp3`, and `mtp4` on Vulkan and CUDA, plus `off`, `mtp2`, and `mtp3` on ROCm. `mtp6` and `mtp8` are omitted from the default sweep because the November 2026 runs confirmed `mtp3` is the peak and `mtp8` drops 37%.

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
| LibreChat | `revan` | `http://127.0.0.1:8080/v1`, `http://skrye.<tailnet>:8080/v1`, `http://zannah.<tailnet>:8080/v1` | `qwen3.5-9b` on `revan` (titles, activity labels, memory), `inkling-2-mini` on `skrye`, `qwen3.8-27b` on `zannah` |
| Silo | `revan` | `http://127.0.0.1:8080/v1` | `qwen3-embedding-0.6b` (media recommendations) |
| Moltis | `skrye`, `zannah`, `traya` | `http://127.0.0.1:8080/v1` | `qwen3-embedding-0.6b` (agent memory) |
| Gatus and Homepage | `revan` | `http://127.0.0.1:8080/health`, `/running`, Tailscale `8080` links | Health and loaded-model monitoring across `revan`, `skrye`, and `zannah` |

For the GPU trade-off analysis on `revan` between its current 16 GB RTX 2000e Ada (`vram16`) and a 22 GB modded RTX 2080 Ti (`vram22`), see [RTX-2000e-Ada Generation-vs-2080Ti-22GB.md](RTX-2000e-Ada%20Generation-vs-2080Ti-22GB.md).
