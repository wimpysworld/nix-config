# Ollama vs llama.cpp on Strix Halo

> AMD Ryzen AI Max+ 395 (gfx1151, RDNA3.5) · 128 GB LPDDR5X · Framework Desktop mainboard · NixOS 25.11 · Linux 6.19.11 · Ollama 0.20.6 · llama.cpp b8775 · ROCm 7.2.1 · linux-firmware 20260309
> Covers both Traya hosts (master and padawan). ZeroClaw connects via OpenAI-compatible API on either backend.

---

## 1. Hardware Context

Each host: AMD Ryzen AI Max+ 395 (Strix Halo), 128 GB unified LPDDR5X, ~270 GB/s peak / ~212 GB/s practical memory bandwidth.

**Practical memory budget:** reserve ~20-30 GB for NixOS, desktop, and dev tools, leaving ~100-110 GB for inference. Ollama and llama-server load one inference model at a time; all recommended models fit comfortably in 128 GB with space for context windows.

MoE model throughput is governed by active parameters, not total parameters. A 30B MoE with 3B active runs faster than a 7B dense model. Large dense models (27B+) are memory-bandwidth-ceilinged at ~10-11 tok/s regardless of backend.

---

## 2. Backend Comparison: Ollama vs llama.cpp

### Measured benchmarks

5-run means across all four runners. Ollama uses the default vendor model tag, which is typically standard Q4_K_M (~4.5 bpw); llama.cpp runs use Unsloth UD-Q4_K_XL from Hugging Face with `-fa 1 --mmap 0`, which is required on Strix Halo to avoid crashes and slowdowns. Exception: gemma4:e2b and gemma4:e4b use UD-Q6_K_XL (see ‡ footnote) because the Q6_K floor is required for audio reliability (see §7); all other models use UD-Q4_K_XL. This is not a pure backend comparison: UD-Q4_K_XL is an imatrix-calibrated "dynamic" quant that upcasts important tensors to Q5_K while leaving most weights at Q4_K, yielding a modestly larger file and materially lower KL divergence against the full-precision reference than Q4_K_M. Unsloth's own measurements put imatrix quants at roughly 5-10% slower to decode than plain k-quants at the same bit width, so on token-generation throughput the quant choice slightly favours Ollama; the figures in the table are raw, unadjusted measurements, so where llama.cpp still leads by a wide margin (notably gpt-oss:20b and the Qwen3.5 MoEs) the true backend advantage is larger than it appears, since llama.cpp posts those numbers while carrying the slower quant. Models marked † are reference points, not production candidates. Software versions: Ollama 0.20.6, llama.cpp b8775, Linux 6.19.11, ROCm 7.2.1.

| Model | Architecture | ROCm Ollama | Vulkan Ollama | ROCm llama-bench | Vulkan llama-bench |
|---|---|---|---|---|---|
| gemma4:e2b‡ | Dense (2.3B eff.) | 87.35 | 45.77 | 72.25 | 80.26 |
| gemma4:e4b‡ | Dense (4.5B eff.) | 51.05 | 25.90 | 41.05 | 42.93 |
| gemma4:26b | MoE (3.8B active) | 47.97 | 28.84 | 45.61 | 50.30 |
| gemma4:31b† | Dense (30.7B) | 10.14 | 10.30 | 10.35 | 10.68 |
| gpt-oss:20b | MoE (3.6B active) | 44.27 | 46.01 | 76.23 | 82.99 |
| qwen3:1.7b† | Dense (1.7B) | 123.51 | 117.32 | 136.43 | 150.22 |
| qwen3-coder-next | MoE (~3B active) | 33.25 | 35.36 | 38.04 | 44.77 |
| qwen3.5:9b† | Dense (9B) | 32.16 | 32.43 | 34.20 | 36.25 |
| qwen3.5:27b† | Dense (27B) | 11.04 | 11.19 | 11.56 | 12.10 |
| qwen3.5:35b-a3b | MoE (3.3B active) | 42.90 | 44.17 | 48.24 | 57.72 |

† Reference model, not a production candidate.  
‡ llama-bench uses UD-Q6_K_XL (required for audio reliability; see §7); Ollama uses the default Q4_K_M tag. These rows are not a pure backend comparison - the quant difference accounts for the reversal where ROCm Ollama outperforms Vulkan llama-bench.  

### What changed vs the previous benchmark run

Ollama upgraded from 0.20.2 to 0.20.6; llama.cpp upgraded from b8667 to b8775; `--mmap 0` now applied to all llama-bench runs (previously `--mmap` was not passed at all).

Key deltas (new vs old Vulkan llama-bench, the headline metric):

| Model | Previous | New | Change |
|---|---|---|---|
| gemma4:e2b¶ | 99.21 | 80.26 | -18.95 (-19.1%) |
| gemma4:e4b¶ | 54.39 | 42.93 | -11.46 (-21.1%) |
| gemma4:26b | 49.58 | 50.30 | +0.72 (+1.5%) |
| gemma4:31b† | 10.61 | 10.68 | +0.07 (+0.7%) |
| gpt-oss:20b | 80.64 | 82.99 | +2.35 (+2.9%) |
| qwen3:1.7b† | 147.47 | 150.22 | +2.75 (+1.9%) |
| qwen3-coder-next | 43.39 | 44.77 | +1.38 (+3.2%) |
| qwen3.5:9b† | 34.35 | 36.25 | +1.90 (+5.5%) |
| qwen3.5:27b† | 11.89 | 12.10 | +0.21 (+1.8%) |
| qwen3.5:35b-a3b | 55.12 | 57.72 | +2.60 (+4.7%) |

¶ Not like-for-like: previous figure is UD-Q4_K_XL, new figure is UD-Q6_K_XL. The E2B and E4B benchmarks now use the heavier quant required for audio reliability (see §7), so the delta reflects the quant change, not a regression in llama.cpp.

ROCm Ollama changed more substantially for Gemma models: gemma4:e2b rose from 65.80 to 87.47 (+33%), gemma4:e4b from 42.77 to 53.06 (+24%), gemma4:26b from 43.13 to 47.97 (+11%). This is likely due to Ollama 0.20.6 improvements to ROCm dispatch for small-to-mid Gemma MoE/dense models. Vulkan Ollama for Gemma models dropped slightly (gemma4:e2b 50.39 → 44.75, gemma4:e4b 27.33 → 26.52), narrowing the ROCm/Vulkan spread but not changing the ROCm dominance conclusion.

The qwen3-coder-next warmup anomaly (previous ‡ note) is resolved. Root cause: the first llama.cpp run was starting while Ollama still held a model resident, and LRU eviction of that Ollama model partway through the first run dragged the result down. The benchmark script now terminates Ollama and llama.cpp and clears loaded models from memory at the end of each 5-run set, giving a clean baseline for the next model.

### ROCm vs Vulkan on Ollama

The faster Ollama backend is model-family dependent. Gemma models run substantially faster on ROCm Ollama: gemma4:e2b is 91% faster on ROCm (87.35 vs 45.77), gemma4:e4b is 97% faster (51.05 vs 25.90), gemma4:26b is 66% faster (47.97 vs 28.84). Qwen and gpt-oss MoE models favour Vulkan Ollama by a smaller margin: qwen3.5:35b-a3b +3% (44.17 vs 42.90), qwen3-coder-next +6% (35.36 vs 33.25), gpt-oss:20b +4% (46.01 vs 44.27). Dense large models are near-parity on both backends.

For a mixed production stack spanning both model families, neither Ollama backend wins outright. This is one of the motivations for migrating to llama-server.

### The MoE vs dense bandwidth-ceiling insight

Large dense models (27B+) are memory-bandwidth-ceilinged at ~10-12 tok/s regardless of backend - the bottleneck is LPDDR5X throughput, not inference overhead. MoE models and small dense models are compute-bound and show meaningful backend differences. The vulkan llama-bench advantage over the best Ollama backend: qwen3.5:35b-a3b +31%, qwen3-coder-next +27%, gemma4:26b +5%, gpt-oss:20b +80%.

The E2B and E4B relationship reverses: ROCm Ollama (Q4_K_M) outperforms Vulkan llama-bench (UD-Q6_K_XL) - 87.35 vs 80.26 for E2B, 51.05 vs 42.93 for E4B. The heavier quant required for audio reliability drops llama-bench throughput below Ollama's lighter Q4_K_M baseline. This is an intentional trade: audio capability over raw decode speed.

### The case for llama-server

Vulkan llama-server delivers the highest throughput across all model families and eliminates the Gemma/Qwen backend split. For production models: qwen3.5:35b-a3b reaches 57.72 tok/s (+31% over best Ollama), qwen3-coder-next reaches 44.77 tok/s (+27%). For gemma4:e4b the case for llama-server is not throughput - ROCm Ollama on Q4_K_M (51.05 tok/s) is faster than Vulkan llama-bench on UD-Q6_K_XL (42.93 tok/s) - but audio reliability: only llama.cpp exposes the Q6_K quant required for stable audio on clips beyond ~17 seconds, and only llama.cpp has a non-experimental conformer encoder path. The migration is a config-only change - ZeroClaw connects via OpenAI-compatible API on either backend, so no agent code changes are required.

---

## 3. Ollama Configuration

### Vulkan backend

Use `pkgs.ollama-vulkan`. The existing Ollama mixin selects this automatically when `host.gpu.compute.acceleration = "vulkan"`. Both Traya hosts have `acceleration = "vulkan"` in the registry.

Ollama Vulkan works correctly on Strix Halo gfx1151 with Ollama 0.20.2. The following issues were previously reported but are not observed in practice:

- iGPU VRAM detection: no detection issue observed; full unified memory is visible on the Vulkan path.
- MoE model output: no garbled output observed with `gemma4:e4b` or `qwen3.5:35b-a3b`. The earlier recommendation to avoid Vulkan was based on unverified reports and is retracted.

**Do not set `rocmOverrideGfx`.** Ollama 0.18+ bundles ROCm 7.2 with native gfx1151 detection. `HSA_OVERRIDE_GFX_VERSION=11.5.1` is no longer required and can cause issues. The NixOS `services.ollama.rocmOverrideGfx` option must not be set for this hardware.

### Environment variables

Add these to `services.ollama.environmentVariables` in the Ollama mixin's `isInference` block:

| Variable | Value | Rationale |
|---|---|---|
| `OLLAMA_FLASH_ATTENTION` | `"1"` | Faster prompt processing. |


### Nix configuration

Proposed `services.ollama` block for `nixos/_mixins/server/ollama/default.nix`:

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-vulkan;
  host = if host.is.server then "0.0.0.0" else "127.0.0.1";
  loadModels = allModels;
  environmentVariables = {
    OLLAMA_FLASH_ATTENTION = "1";
  };
};
```

---

## 4. llama-server Configuration

### Required Strix Halo flags

Always start llama.cpp on Strix Halo with flash attention and mmap disabled: `-fa 1 --mmap 0`. This applies to `llama-server`, `llama-bench`, and equivalent llama.cpp tools. Older notes may refer to `--no-mmap`, but current llama.cpp tools use the explicit `--mmap 0` form. Omitting either setting causes crashes or avoidable slowdowns on this hardware.

### KV cache quantisation

Not used on Strix Halo. Benchmarking showed `q8_0` KV cache hurts throughput enough that the memory saving is not worth it on 128 GB hardware. The flags are `--cache-type-k q8_0 --cache-type-v q8_0` for llama-server and `OLLAMA_KV_CACHE_TYPE=q8_0` for Ollama - worth revisiting on lower-RAM hardware where fitting a larger model matters more than raw speed.

### Router mode vs llama-swap

Two approaches exist for running multiple models under a single `llama-server` endpoint.

**Native router mode** - shipped December 2025 (PR #17470). Start `llama-server` without `-m` to enable auto-discovery from `--models-dir`. Models load on demand, are evicted by LRU when the count reaches `--models-max`, and are selected per-request via the `model` field. Manual control via `/models/load` and `/models/unload` APIs. Per-model settings go in `--models-preset config.ini`. Marked experimental.

**llama-swap** - a Go binary (~3K stars, https://github.com/mostlygeek/llama-swap) that sits in front of one or more `llama-server` processes and routes requests by model name. More mature than the native router for mixed generation/embedding workloads. Key features: always-on groups (an embedding model stays resident while generation models swap in and out), per-model TTLs, mixed backends, and `/v1/embeddings` routing. The more reliable choice for production use until the native router matures.

Ollama's integrated load/unload is more polished than either option above. Both llama-server router mode and llama-swap are functional but require more manual configuration.

### Embedding server split

`llama-server` exposes an OpenAI-compatible `/v1/embeddings` endpoint alongside a custom `/embedding` endpoint. One operational requirement for Qwen3-Embedding models: `--pooling last` must be passed explicitly at startup - the GGUF metadata does not carry this flag, so omitting it produces incorrect embeddings.

`--embedding` mode locks the server to embeddings only. A migration to `llama-server` for embeddings therefore requires two server processes: one for generation, one for embeddings.

### Model pre-seeding

This is the primary operational gap in a llama-server deployment versus Ollama's `services.ollama.loadModels`.

llama.cpp has no dedicated download tool. The `-hf` flag downloads models at runtime to `~/.cache/llama.cpp`, which is unsuitable for a server deployment. The correct pre-seeding tool is `hf` from `pkgs.python3Packages.huggingface-hub`, which provides both the `hf` and `huggingface-cli` commands:

```bash
hf download --repo-type model <org/repo> <file-path>
```

Downloaded files land in the HF hub cache at `~/.cache/huggingface/hub/models--<org>--<repo>/snapshots/<revision>/<file-path>`. The path is a symlink into the `blobs/` content-addressable store - pass the resolved symlink path to `-m`.

**Multi-part models** (e.g. gpt-oss:120b ships as two shards) require each shard downloaded individually. llama-server only needs the first shard passed to `-m`; it discovers the remaining shards automatically from the same directory:

```bash
hf download --repo-type model unsloth/gpt-oss-120b-GGUF \
    UD-Q4_K_XL/gpt-oss-120b-UD-Q4_K_XL-00001-of-00002.gguf
hf download --repo-type model unsloth/gpt-oss-120b-GGUF \
    UD-Q4_K_XL/gpt-oss-120b-UD-Q4_K_XL-00002-of-00002.gguf

llama-server -m /path/to/gpt-oss-120b-UD-Q4_K_XL-00001-of-00002.gguf ...
```

The `benchmark-models` script (`home-manager/_mixins/scripts/benchmark-models/`) encodes the shard list for each model as a comma-separated field in its `MODEL_SPECS` table, downloads each shard in sequence, and resolves the primary shard path through the HF cache structure before passing it to llama-bench. The same pattern applies to the production llama-server pre-seeding oneshot.

The NixOS pattern is a systemd oneshot service that runs the downloads before `llama-server` starts, with models stored under `/var/lib/llama-models/`. This requires a custom module - nixpkgs PR #488117 adds `hfRepo`/`hfFile` options directly to `services.llama-cpp` with download at service start, but it has not yet merged. Until it does, the download oneshot must be written by hand.

---

## 5. Hardware and OS Configuration

### BIOS settings

Current BIOS: version 3.04 (2025-12-09). Update via LVFS: `fwupdmgr update`.

| Setting | Value | Notes |
|---|---|---|
| UMA Frame Buffer Size | 512 MB | Critical. Default may reserve up to 97 GB for GPU, leaving only 31 GB for OS. BIOS path: Advanced → AMD CBS → NBIO → GFX Configuration. |

**Do not leave UMA Frame Buffer Size at its default.** The GPU dynamically claims compute memory via TTM - the BIOS carve-out is not needed for inference.

### GPU clock (DPM)

No clock configuration is required. In `auto` DPM mode the GPU boosts automatically to near-maximum clock (2845 MHz of 2900 MHz peak) during inference workloads and scales back at idle. Both `power_dpm_force_performance_level=high` and `amdgpu.runpm=0` were investigated and found unnecessary - clock scaling works correctly without either tweak.

Verify clock behaviour during inference:

```bash
watch -n1 'cat /sys/class/drm/card1/device/pp_dpm_sclk'
# Expected: highest clock entry marked with * during active inference
```

### GTT memory

The default TTM limit is ~50% of RAM (~64 GB on a 128 GB system). Expand to ~120 GB for LLM workloads:

```nix
# 120 GB expressed in 4 KiB pages: 120 * 1024^3 / 4096 = 31,457,280
boot.extraModprobeConfig = ''
  options ttm pages_limit=31457280
'';
```

`amdgpu.gttsize` is deprecated; use `ttm.pages_limit` only.

**Registry `vram` field:** Both Traya hosts have `vram = 96` in the registry. With TTM expanded to ~120 GB, effective inference memory is ~112-120 GB. The `vram` registry value represents the conservative inference budget used by the Ollama mixin for model tier selection, not physical memory capacity.

### IOMMU

No IOMMU kernel parameter changes are required on Strix Halo. Investigation on the actual hardware confirmed IOMMU was not set, and inference works correctly without `iommu=pt` or `amd_iommu=off`. Recommendations to set these parameters are common in online guides but did not apply here.

### Kernel and firmware requirements

| Requirement | Version | Notes / confidence |
|---|---|---|
| Kernel (non-Ubuntu distros, ROCm 7.2.x on gfx1151) | ≥ 6.18.4 | Confirmed minimum. AMD ROCm RDNA3.5 optimisation docs list 6.18.4 as the first "other distribution" kernel that forms a stable combination with ROCm 7.2.x; earlier kernels are marked unstable/experimental. |
| Kernel (this system) | 6.19.11 | Currently running; satisfies the 6.18.4 floor. Not an AMD-documented minimum. |
| ROCm | ≥ 7.2.0 | Confirmed minimum. ROCm 7.2.0 is the first release with official gfx1151 support; 7.1.x and 6.4.x are listed as unsupported on Strix Halo by AMD's compatibility matrix. 7.2.1 is the current stable track. |
| linux-firmware (avoid) | 20251125 | Confirmed broken. This specific release contains a gfx1151 regression that breaks ROCm on Strix Halo (ROCm issues #5724, #5853; kyuz0 toolboxes notes). |
| linux-firmware (known-good floor) | ≥ 20260110 | Community-confirmed working baseline (kyuz0 toolboxes stable configuration). No AMD-published minimum exists. |
| linux-firmware (this system) | 20260309 | Currently running; above the known-good floor. Not a documented minimum. |

Sources: [AMD ROCm RDNA3.5 system optimisation](https://rocm.docs.amd.com/en/latest/how-to/system-optimization/rdna3-5.html), [ROCm Radeon/Ryzen compatibility matrices](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html), kyuz0/amd-strix-halo-toolboxes issue #45.

NixOS 25.11 ships `pkgs.linuxPackages_latest` on the 6.19 series, which comfortably clears the 6.18.4 floor. Avoid pinning `linux-firmware` to the 20251125 snapshot; any release from 20260110 onward is reported to work.

---

## 6. NixOS Configuration

### Hardware mixin snippet

Hardware-specific settings belong in a host-level config or dedicated hardware mixin, not in the Ollama service mixin:

```nix
{ config, lib, pkgs, ... }:

{
  # Kernel ≥ 6.19.11 required for gfx1151 + ROCm 7.2 stability.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.extraModprobeConfig = ''
    # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
    options ttm pages_limit=31457280
  '';
}
```

### Monitoring

Use `amdgpu_top` v0.11.0 - it introspects all SoC metrics on gfx1151, including GPU clock, utilisation, and power draw.

---

## 7. Model Selection: Inference

### Gemma 4 (Google DeepMind)

Gemma 4 is Google DeepMind's fourth-generation open model family, spanning edge-tier multimodal models to a full 31B dense variant, all with native function calling and configurable thinking mode.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| E2B | 7.2 GB | Dense (2.3B effective) | 128K | Edge-tier, multimodal |
| E4B | 9.6 GB | Dense (4.5B effective) | 128K | Lightweight workhorse, multimodal |
| 26B MoE | 18 GB | MoE, 128 experts, 3.8B active | 256K | Best efficiency/quality ratio |
| 31B | 20 GB | Dense (30.7B) | 256K | Maximum quality, native function calling |

The 26B MoE scores AIME 2026 88.3% versus 89.2% for the 31B dense - a 2% quality trade for meaningfully faster inference (48 tok/s vs 5-10 tok/s). The 31B dense is memory-bandwidth-ceilinged at the same rate as qwen3.5:27b.

#### E2B and E4B: audio and vision variants

The E2B and E4B are the only Gemma 4 variants with audio capability. The 26B and 31B models have no audio encoder.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| E2B | ~3 GB | Dense (2.3B effective) + audio encoder | 128K | Smallest; audio/vision capable |
| E4B (recommended) | ~5 GB | Dense (4.5B effective) + audio encoder | 128K | Better quality; audio/vision capable |

The architecture includes a ~150M vision encoder for image and video input and a ~300M USM-style conformer encoder for audio.

**What works in Ollama today:** image and video input (video via frame extraction, up to 60 seconds at 1 fps through the image path).

**Audio support status:** llama.cpp gained conformer encoder support when PR #21421 merged on or about 12 April 2026. Ollama has shipped audio in an unstable state - audio is passed through the `images` field of `/api/chat` with no dedicated audio endpoint, and issue #15333 (opened 5 April 2026, still open) documents intermittent GGML assertion crashes every 2 to 4 requests on Ollama 0.20.2. The Ollama library model card still shows "Text, Image" despite the `audio` tag. Treat Ollama audio as experimental; llama.cpp is the reliable path.

Audio requires Q6_K quantisation minimum. Q4_K_M fails consistently on clips longer than roughly 17 seconds due to quantisation sensitivity in the tied 262k vocabulary embeddings (PR #21421 author testing; companion PR #21599 forces Q6_K minimum for tied embeddings). Per-clip length is capped at 30 seconds by the model (Google model card). Longer recordings must be chunked before submission - the feature extractor truncates at 30s with `truncation=True`, so VAD or similar segmentation is a practical consequence of that hard limit rather than a documented requirement.

Unsloth's `gemma-3n-E2B-it-GGUF` and `gemma-3n-E4B-it-GGUF` repositories have shipped UD-Q6_K_XL alongside UD-Q4_K_XL since initial upload on 2025-06-30 (commits 0de8bc85 and fbddbc22 respectively, within minutes of the Q4_K_XL uploads). The Q6_K_XL files were not newly published for audio; they have always been available and are now the production choice for E2B and E4B to meet the Q6_K audio floor.

With UD-Q6_K_XL, the backend ranking reverses versus the lighter quant: ROCm Ollama (on Q4_K_M) outperforms Vulkan llama-bench (on UD-Q6_K_XL) for both models - E2B 87.35 vs 80.26, E4B 51.05 vs 42.93. Throughput is traded for audio reliability; the trade is intentional.

Ollama is not a viable production path for audio on these models for two reasons: (1) its audio implementation is experimental and crashes intermittently (issue #15333 - GGML assertion crashes every 2-4 requests on 0.20.2); (2) the default Ollama tag ships Q4_K_M only and does not expose the Q6_K quantisation variants required for reliable audio on longer clips. llama.cpp with UD-Q6_K_XL is the reliable path.

**E2B 5-run means:** ROCm Ollama 87.35 (Q4_K_M), Vulkan Ollama 45.77 (Q4_K_M), ROCm llama-bench 72.25 (UD-Q6_K_XL), Vulkan llama-bench 80.26 (UD-Q6_K_XL).

**E4B 5-run means:** ROCm Ollama 51.05 (Q4_K_M), Vulkan Ollama 25.90 (Q4_K_M), ROCm llama-bench 41.05 (UD-Q6_K_XL), Vulkan llama-bench 42.93 (UD-Q6_K_XL).

Speed on Strix Halo (E4B, production quant UD-Q6_K_XL): ROCm Ollama 51.05 tok/s is the fastest runner but uses the lighter Q4_K_M quant which fails audio beyond ~17s. Vulkan llama-bench reaches 42.93 tok/s on UD-Q6_K_XL - the production audio-capable path. At this size the model is compute-bound, not memory-bandwidth-bound.

### Qwen 3.5 (Alibaba)

Qwen 3.5 is Alibaba's frontier general-purpose model series, explicitly designed for the "agentic AI era." The architecture combines Gated Delta Networks with sparse MoE, yielding strong knowledge recall and tool use across a wide size range.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| 9B | 6.6 GB | Hybrid MoE | 256K | Light tasks |
| 27B | 17 GB | Dense, DeltaNet hybrid | 256K | All 27B params active per token |
| 35B | 24 GB | Hybrid MoE | 256K | MoE general-purpose variant |
| 122B | 81 GB | Hybrid MoE | 256K | Technically fits but impractical on a workstation |

The flagship 397B-A17B scores BFCL-V4 72.9, MCP-Mark 46.1, and TAU2-Bench 86.7. Smaller variants inherit the agentic architecture. Strong knowledge recall (80.6 average versus Gemma 4 31B's 61.3), 201 languages, vision, tool use, and thinking mode.

The 27B uses a Gated DeltaNet hybrid architecture - linear attention alternating with standard attention, new to the Qwen3.5 generation. All 27B parameters are active per forward pass. SWE-Bench Verified 72.4%, LiveCodeBench v6 80.7%, IFEval 95.0%, TAU2-Bench 79.0%. Native multimodal (text, image, video). Despite being smaller on disk than the 35B MoE, it scores higher on every coding benchmark - but is memory-bandwidth-ceilinged at ~11 tok/s.

**Community hard-task testing** on Strix Halo (frank-besson/llama-strix-halo benchmark, 30 tasks) found qwen3.5:35b-a3b scores 10/10 on agentic patterns but 0/6 on structured output constraints and instruction following - high variance on tasks requiring strict output formatting. This reinforces a role split: use qwen3.5:35b-a3b for agent loops where the scaffold can self-correct, and qwen3.5:27b for tasks requiring one-shot precision and structured output.

---

## 8. Model Selection: Embedding

### qwen3-embedding (Alibaba)

| Variant | Disk (Q4_K_M) | Disk (Q8_0) | Context | Dimensions |
|---|---|---|---|---|
| 0.6B | 639 MB | ~1.2 GB | 32K | Up to 4096 (flexible 32-4096) |
| 4B | 2.5 GB | ~5 GB | 40K | Up to 4096 |
| 8B (latest) | 4.7 GB | ~9 GB | 40K | Up to 4096 |

MTEB multilingual leaderboard #1 (8B variant, score 70.58, June 2025). Code retrieval capable. 100+ languages. The 32K-40K context window can embed entire source files - critical for code-aware memory in a coding agent.

**MTEB benchmarks (retrieval / code retrieval):**

| Variant | MTEB Retrieval | MTEB Code |
|---|---|---|
| 0.6B | baseline | baseline |
| 4B | +4.96 vs 0.6B | +4.65 vs 0.6B |
| 8B | +1.28 vs 4B | +0.62 vs 4B (80.06 vs 80.68) |

The quality plateau is at 4B, not 8B. The 4B-to-8B delta (0.62 points on code retrieval) is noise-level in practice; the 4B processes roughly 2x the tokens per second of the 8B.

**Quantisation:** embedding quality degrades more with aggressive quantisation than generation quality does. The default Ollama tag uses Q4_K_M. On this hardware (128 GB), use Q8_0: pull `qwen3-embedding:4b-q8_0`. Memory cost is ~5 GB at Q8 versus ~2.5 GB at Q4 - trivial on 128 GB.

**Context window:** the official Ollama Modelfile for `qwen3-embedding:4b-q8_0` sets `num_ctx` to the model's full 40,960-token native context. No additional configuration is required.

**Reranker note:** a Qwen3-Reranker-4B on top of qwen3-embedding:0.6B scores 81.20 on MTEB Code, higher than qwen3-embedding:8B alone (80.68). Worth considering as a future enhancement if retrieval quality becomes a bottleneck after deployment.

### Alternatives evaluated and set aside

| Model | Disk | Context | Reason set aside |
|---|---|---|---|
| nomic-embed-text-v2-moe | 958 MB | 512 tokens | Context too short for code chunks |
| embeddinggemma | 622 MB | 2K tokens | No advantage over qwen3-embedding at 2K context |

---

## 9. Recommended Stack

### Model table

| Slot | Model | Disk | Active params | Context | tok/s | Primary use |
|---|---|---|---|---|---|---|
| Coding | qwen3-coder-next | 51 GB | 3B (MoE) | 256K | 44.77 | Agentic coding, PR review, multi-step |
| General | qwen3.5:35b-a3b | 24 GB | 3.3B (MoE) | 256K | 57.72 | Structured output, precision tasks, general reasoning |
| Small / media | gemma4:e4b | ~5 GB | 4.5B (eff) | 128K | 42.93§ | Summarisation, image/video triage, fast tasks |
| Embedding | qwen3-embedding:4b-q8_0 | ~5 GB | 4B | 40K | - | Memory retrieval |
| **Total** | | **~85 GB** | | | | |

Total disk ~85 GB leaves ~25 GB headroom in the 110 GB practical budget.

§ gemma4:e4b tok/s is Vulkan llama-bench on UD-Q6_K_XL - the production quant for audio reliability. ROCm Ollama reaches 51.05 tok/s on Q4_K_M but cannot be used for audio beyond ~17s clips.

### ZeroClaw config pattern

Current config uses Ollama endpoints. Once the llama-server migration completes, replace `ollama/` model prefixes with `openai/` and update `api_base` to the llama-server port (timing TBD).

```toml
[[model_list]]
model_name = "primary"
model = "ollama/qwen3-coder-next"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "general"
model = "ollama/qwen3.5:35b-a3b"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "small"
model = "ollama/gemma4:e4b"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "frontier"
model = "anthropic/claude-sonnet-4-5"

[agents.defaults.model]
primary = "primary"
fallbacks = ["frontier"]

[memory]
embedding_model = "ollama/qwen3-embedding:4b-q8_0"
embedding_base = "http://<host-container-ip>:11434/v1"
```

### Rationale per slot

**qwen3-coder-next as coding primary:** 80B total / 3B active MoE - throughput governed by active parameters, not total. Measured 44.77 tok/s (Vulkan llama-bench) versus qwen3.5:27b's 12.10 tok/s, a 3.7x speed advantage. SWE-Bench Verified 70.6% vs qwen3.5:27b's 72.4% - a marginal quality trade. LiveCodeBench 58.9% vs 80.7% - weaker on single-shot algorithmic tasks; qwen3.5:35b-a3b covers that precision gap. Designed for agentic retry loops: Pass@5 rank 1 on SWE-rebench. 256K context for repo-scale work.

**qwen3.5:35b-a3b as general:** 3.3B active MoE, 256K context. Measured 57.72 tok/s (Vulkan llama-bench). Community hard-task testing scores 10/10 on agentic patterns; use for structured output, precision tasks, and the algorithmic reasoning gap qwen3-coder-next leaves open. Self-correction in an agent loop compensates for its 0/6 structured output score on hard-task benchmarks.

**gemma4:e4b as small/media model:** the only local model in the stack with audio and video capability - neither of the larger Gemma 4 models has an audio encoder. Image and video (frame sequences up to 60 seconds) work today. Audio transcription and understanding are model-supported but pending llama.cpp and Ollama implementation; use Q6_K when audio lands. At ~5 GB and 42.93 tok/s (Vulkan llama-bench, 5-run mean, UD-Q6_K_XL - the production quant required for audio reliability) it handles summarisation, fast triage, and lightweight tasks without loading a larger model. ROCm Ollama reaches 51.05 tok/s on Q4_K_M but that quant fails audio on clips beyond ~17s, so the Q6_K floor is non-negotiable for the audio role.

**qwen3-embedding:4b-q8_0 as embedding:** load permanently alongside inference models. The 4B sits at the quality optimum: +4.96 MTEB retrieval and +4.65 MTEB Code over the 0.6B, with the 8B adding only 0.62 further points at half the throughput. Q8_0 preserves embedding fidelity that Q4_K_M would compromise; the ~5 GB memory cost is trivial on 128 GB.

**Frontier fallback:** local models handle the 80-90% routine case; Claude handles deep research and complex multi-step reasoning that exceeds the local tier.

### Why ZeroClaw needs embeddings

ZeroClaw's memory pipeline has three stages: hot cache, FTS5 keyword search, and vector similarity search. Embeddings unlock stage 3 - semantic memory recall finds relevant memories even when the query shares no exact keywords with stored entries. Without embeddings, ZeroClaw falls back to `NoopEmbedding`, which returns empty vectors and limits retrieval to keyword matching only. The `EmbeddingProvider` trait uses any OpenAI-compatible `/embeddings` endpoint, so Ollama and llama-server embedding models work natively.

For agents doing multi-session agentic work - PR reviews that reference earlier discussions, blog drafts that build on prior research - hybrid retrieval is meaningfully better than keyword-only.

### Split-host strategy

Run the same model stack on both Traya hosts (master and padawan).

Both hosts run identical agent configurations. Different model families produce different output styles and tool-calling behaviours, creating inconsistent quality that is harder to evaluate and tune. One Nix configuration, one set of system prompts tuned for one model's behaviour, one set of known failure modes. Identical stacks mean either host can substitute for the other if one goes down - which is the point of the warm-standby arrangement.

### Models evaluated and set aside

| Model | Reason |
|---|---|
| qwen3.5:122b | 81 GB leaves ~29 GB for NixOS + desktop + context; ~3.4 tok/s impractical for interactive work |
| qwen3.5:27b | Dense 27B; measured 12.10 tok/s (Vulkan llama-bench) - bandwidth-ceilinged regardless of backend. qwen3-coder-next provides 3.7x throughput at comparable SWE-Bench quality (70.6% vs 72.4%). |
| gemma4:31b | Dense 30.7B; measured 10.68 tok/s (Vulkan llama-bench) - same bandwidth ceiling as qwen3.5:27b. gemma4:26b MoE delivers 50.30 tok/s at near-identical quality. |
| gemma4:26b | MoE, 3.8B active, 50.30 tok/s (Vulkan llama-bench) measured. Considered as alternative general model; qwen3.5:35b-a3b preferred for stronger structured output and Qwen family consistency. |
| qwen3-coder:30b | Superseded; old Qwen3 architecture with 3.3B active params scores 50.3% SWE-Bench vs qwen3-coder-next's 70.6% |
| qwen3-embedding:0.6b | Quality plateau at 4B; 0.6B suitable only for resource-constrained hardware |
| qwen3-embedding:8b | 4B-to-8B delta is 0.62 points on code retrieval; 4B at Q8_0 is the quality/throughput optimum |
| nomic-embed-text-v2-moe | 512-token context too short for code chunks |
| embeddinggemma | No advantage over qwen3-embedding at 2K context |

---

## 10. NPU: Future Consideration

The Ryzen AI Max+ 395 includes 40 XDNA2 neural processing units - dedicated silicon for matrix operations, separate from the iGPU.

**Current state (April 2026):**

- **llama.cpp:** no upstream NPU backend. A community fork by BrandedTamarasu-glitch (March 2026) dispatches GEMM ops via `mlir-aie` xclbins and XRT 2.21.75, achieving 43.7 tok/s on Llama-3.1-8B Q4_K_M at 0.947 J/tok - matching Vulkan iGPU decode speed while drawing ~10 W less. Not merged upstream.
- **Ollama:** no NPU support. Two open feature requests (issues #5186 and #11199) with 100+ upvotes each, no roadmap.
- **Linux driver:** `amdxdna` landed in kernel 6.14 (mainline). Userspace requires XRT + xrt-plugin-amdxdna shim; custom NixOS packaging would be needed.

**Why not now:** the NPU and iGPU share the LPDDR5X memory bus. For large memory-bound models, neither can exceed the bus throughput - the NPU cannot outperform what Vulkan iGPU already delivers.

**Why it matters later:** the NPU and iGPU are separate compute units. Once tooling matures, both can run concurrently - the NPU serving the embedding model while the iGPU handles generation, eliminating the current serialisation where embedding requests stall generation. The sub-1 J/tok efficiency figure also becomes meaningful for unattended overnight agent workloads.

**Trigger to revisit:** `ggml-hsa` merging into llama.cpp upstream, or llama-server gaining explicit NPU backend support.

---

## 11. References

| Resource | URL |
|---|---|
| AMD RDNA3.5 system optimisation (ROCm docs) | https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html |
| Ollama GEMV fusion buffer overlap bug (#15261) | https://github.com/ollama/ollama/issues/15261 |
| Ollama ROCm working guide for Strix Halo (#14855) | https://github.com/ollama/ollama/issues/14855 |
| ROCm/ROCm gfx1151 amd-smi N/A issue (#6035) | https://github.com/ROCm/ROCm/issues/6035 |
| Framework community VRAM allocation | https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081 |
| NixOS ollama module source | https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/ollama.nix |
| Power modes performance guide | https://strixhalo-homelab.d7.wtf/Guides/Power-Modes-and-Performance |
| Ollama - Gemma 4 | https://ollama.com/library/gemma4 |
| Ollama - Qwen 3.5 | https://ollama.com/library/qwen3.5 |
| Ollama - qwen3-embedding | https://ollama.com/library/qwen3-embedding |
| Ollama - nomic-embed-text-v2-moe | https://ollama.com/library/nomic-embed-text-v2-moe |
| Ollama - embeddinggemma | https://ollama.com/library/embeddinggemma |
| BenchLM - Gemma 4 31B vs Qwen3.5-27B | https://benchlm.ai/compare/gemma-4-31b-vs-qwen3-5-27b |
| Alibaba Cloud - Qwen3.5 | https://www.alibabacloud.com/blog/602894 |
| Hacker News - Strix Halo bandwidth | https://news.ycombinator.com/item?id=45877149 |
| llama-swap | https://github.com/mostlygeek/llama-swap |
| nixpkgs PR #488117 - llama-cpp hfRepo/hfFile | https://github.com/NixOS/nixpkgs/pull/488117 |
