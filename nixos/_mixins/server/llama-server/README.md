# Local inference with llama-server

llama-swap serves local models on demand through an OpenAI-compatible API.
Each inference host selects its own models by GPU memory from the shared
[model policy](model-policy.nix).

## Current model policy

The policy applies to all inference hosts. Inkling 2 Mini is the mixture-of-experts
model (`moe`), and Qwen3.8 27B is the dense model (`dense`). The service and
benchmarks use the shared `pkgs.llama-cpp` package at b12628.

| VRAM tier | Inkling 2 Mini (`inkling-2-mini`) | Qwen3.8 27B (`qwen3.8-27b`) | Small / media | Embedding |
|---|---|---|---|---|
| `vram64` | UD-Q4_K_XL, 256K | UD-Q4_K_XL, 256K | `gemma4-e4b` | Qwen3 Embedding 0.6B |
| `vram32` | UD-Q4_K_XL, 32K | UD-Q4_K_XL, 64K | `gemma4-e4b` | Qwen3 Embedding 0.6B |
| `vram22` | UD-Q4_K_XL, 16K | UD-Q4_K_XL, 32K | `gemma4-e4b` | Qwen3 Embedding 0.6B |
| `vram16` | UD-IQ3_XXS, 16K | UD-Q3_K_XL, 16K | `gemma4-e4b` | Qwen3 Embedding 0.6B |
| `vram8` | Not served | Not served | `gemma4-e2b` | Qwen3 Embedding 0.6B |

The generation columns show quantisation and context in tokens. Both new models
use one slot and disable context shifting. On the 64 GiB Vulkan hosts, both use
262,144 tokens of context. On that tier, Inkling uses a micro-batch of 128,
and Qwen uses multi-token prediction (MTP) with up to two draft tokens. Other
tiers do not enable MTP.

The small media models keep UD-Q6_K_XL and 128K context. Each loads its
matching BF16 projector for image and audio input. All tiers use
`qwen3-embedding-0.6b` at Q8_0 with 8,192 tokens of context.

## Run benchmarks

Run `benchmark-models-all` to benchmark `inkling-2-mini` and `qwen3.8-27b`.
Run `benchmark-models MODEL [runs]` to benchmark one model. Specify `gemma4-e2b`,
`gemma4-e4b` or `qwen3-embedding-0.6b` to benchmark a media or embedding model.
The commands use packaged llama.cpp binaries and pinned snapshots in the
Hugging Face cache. For the two text generators, the host's VRAM tier sets the
quantisation. Text generation benchmarks use the shared model sampler policy.
Synthetic `llama-bench` tests do not sample tokens.

### Strix Halo results

An earlier benchmark compared Vulkan and ROCm on Strix Halo with llama.cpp
b12628. Both backends used the same UD-Q4_K_XL file for each model. Each case
used an 8,192-token context, a 4,096-token prompt and 512 output tokens. These
runs used greedy sampling, not the current model samplers. The table shows
the median total request time over three runs after a warm-up:

| Model | MTP draft limit | Vulkan (s) | ROCm (s) |
|---|---:|---:|---:|
| Inkling 2 Mini | Off | 27.80 | 34.79 |
| Qwen3.8 27B | Off | 52.66 | 54.16 |
| Qwen3.8 27B | 2 | 31.17 | 32.44 |
| Qwen3.8 27B | 3 | 30.68 | 30.09 |

On Vulkan, Qwen with a draft limit of two decoded at 25.26 tokens per second
versus 12.13 without MTP. A limit of three was slightly faster, but fewer
draft tokens were accepted (70% versus 87%).

In a separate Vulkan run, Inkling processed a 258,207-token prompt without
truncation. Prompt processing alone took about 41 minutes and 33 seconds.
Neither run establishes retrieval quality at long context or CUDA performance.

---

## 1. Hardware Context

**Strix Halo inference hosts (×2):** AMD Ryzen AI Max+ 395, 128 GB unified LPDDR5X, ~270 GB/s peak / ~212 GB/s practical memory bandwidth. One host is on the same LAN as Revan; the other is at a remote site, reachable over Tailscale.

**Practical memory budget:** reserve ~56 GB for NixOS, desktop, and dev tools, leaving ~72 GB for inference. This budget supports the selected local model set for each host, with llama-swap starting each backend on demand rather than preloading everything at boot.

**Revan hub:** Intel i9 9900K (downclocked, 65W), 64 GB RAM, NixOS. An NVIDIA RTX 2000e Ada Generation (16 GB GDDR6 ECC, 50W bus-powered, CUDA) runs local models and Jellyfin transcoding. Revan can send requests to another host's llama-swap endpoint.

---

## 2. Historical backend comparison: Ollama vs llama.cpp

These measurements informed the move from Ollama to llama-server. They use
Ollama 0.20.6 and llama.cpp b8775 on Strix Halo, not the current model policy.

### Measured benchmarks

The table shows mean decode throughput over five runs. Ollama used the default
vendor tags, typically Q4_K_M. llama-bench used Unsloth UD-Q4_K_XL on most
models and UD-Q6_K_XL on Gemma E2B and E4B for audio reliability. Differences
in quantisation affect the comparison. The host ran Linux 6.19.11 and ROCm 7.2.1.

| Model | Architecture | ROCm Ollama | Vulkan Ollama | ROCm llama-bench | Vulkan llama-bench |
|---|---|---|---|---|---|
| gemma4:e2b‡ | Dense (2.3B eff.) | 88.74 | 46.23 | 73.42 | 82.51 |
| gemma4:e4b‡ | Dense (4.5B eff.) | 54.06 | 26.81 | 41.83 | 43.42 |
| gemma4:26b | MoE (3.8B active) | 49.57 | 29.60 | 46.38 | 51.05 |
| gemma4:31b† | Dense (30.7B) | 10.30 | 10.25 | 10.40 | 10.79 |
| qwen2.5-coder:7b | Dense (7B) | 45.04 | 44.39 | 45.08 | 45.19 |
| qwen2.5-coder:14b | Dense (14B) | 23.87 | 24.10 | 23.81 | 24.44 |
| qwen3:1.7b† | Dense (1.7B) | 123.54 | 117.16 | 136.60 | 149.86 |
| qwen3-coder:30b-a3b | MoE (3.3B active) | 56.70 | 68.50 | 70.71 | 88.00 |
| qwen3-coder-next | MoE (~3B active) | 34.38 | 35.59 | 38.27 | 44.87 |
| qwen3.5:9b | Dense (9B) | 32.14 | 32.37 | 34.20 | 36.15 |
| qwen3.5:27b† | Dense (27B) | 11.05 | 11.19 | 11.56 | 12.10 |
| qwen3.5:35b-a3b | MoE (3.3B active) | 42.08 | 44.15 | 48.37 | 57.72 |
| rnj-1:8b | Dense (8B) | 37.11 | 37.28 | 36.80 | 37.92 |

† Reference model, not a production candidate.
‡ See the [Gemma audio notes](#e2b-and-e4b-audio-and-vision-variants) for the quantisation requirement.

### What changed vs the previous benchmark run

This run keeps the same software stack as the previous pass, but uses the revised benchmark harness with a fixed 512-token decode task and a synthetic 512-token prompt-processing test. The headline Vulkan llama-bench decode figures moved only slightly, which is useful in itself - the revised harness kept the earlier ranking intact.

Key deltas (new vs old Vulkan llama-bench, the headline metric):

| Model | Previous | New | Change |
|---|---|---|---|
| gemma4:e2b | 80.26 | 82.51 | +2.25 (+2.8%) |
| gemma4:e4b | 42.93 | 43.42 | +0.49 (+1.1%) |
| gemma4:26b | 50.30 | 51.05 | +0.75 (+1.5%) |
| gemma4:31b† | 10.68 | 10.79 | +0.11 (+1.0%) |
| qwen3:1.7b† | 150.22 | 149.86 | -0.36 (-0.2%) |
| qwen3-coder-next | 44.77 | 44.87 | +0.10 (+0.2%) |
| qwen3.5:9b | 36.25 | 36.15 | -0.10 (-0.3%) |
| qwen3.5:27b† | 12.10 | 12.10 | ~0.00 |
| qwen3.5:35b-a3b | 57.72 | 57.72 | ~0.00 |

Models added in that run:

- `qwen2.5-coder:7b` - 45.19 tok/s on Vulkan llama-bench, near-parity with Ollama.
- `qwen2.5-coder:14b` - 24.44 tok/s on Vulkan llama-bench, again near-parity.
- `qwen3-coder:30b-a3b` - 88.00 tok/s on Vulkan llama-bench, the fastest coding model in that run.
- `rnj-1:8b` - 37.92 tok/s on Vulkan llama-bench, with decode throughput close to both Ollama backends.

### ROCm vs Vulkan on Ollama

The faster Ollama backend depended on the model family. Gemma models were faster on ROCm Ollama: gemma4:e2b by 92% (88.74 vs 46.23), gemma4:e4b by 102% (54.06 vs 26.81), gemma4:26b by 67% (49.57 vs 29.60). `qwen3-coder:30b-a3b` ran at 68.50 tok/s on Vulkan Ollama and 56.70 tok/s on ROCm. `qwen3-coder-next` and `qwen3.5:35b-a3b` also favoured Vulkan Ollama, but by smaller margins. `qwen2.5-coder:7b`, `qwen2.5-coder:14b`, `qwen3.5:9b`, and `rnj-1:8b` were close to parity.

For a mixed production stack spanning both model families, neither Ollama backend wins outright. This is one of the motivations for migrating to llama-server.

### The MoE vs dense bandwidth-ceiling insight

The large dense models in that run reached about 10-12 tok/s across backends without speculative decoding. The bottleneck was LPDDR5X throughput. The mixture-of-experts models showed larger differences: Vulkan llama-bench beat the fastest Ollama backend by 31% for qwen3.5:35b-a3b, 26% for qwen3-coder-next, 28% for qwen3-coder:30b-a3b, and 3% for gemma4:26b.

The E2B and E4B relationship still reverses: ROCm Ollama (Q4_K_M) outperforms Vulkan llama-bench (UD-Q6_K_XL) - 88.74 vs 82.51 for E2B, 54.06 vs 43.42 for E4B. The heavier quant required for audio reliability drops llama-bench throughput below Ollama's lighter Q4_K_M baseline. This is an intentional trade: audio capability over raw decode speed.

Prompt-processing results add one more useful signal. Ollama still shows a first-run prompt throughput dip after backend restart, while llama-bench prompt figures stay much tighter run to run. That does not change the decode ranking, but it does support the broader operational conclusion that the llama.cpp path is the steadier measurement and serving path.

### The case for llama-server

Vulkan llama.cpp gave the highest throughput for most models in that run and removed the need to choose an Ollama backend per family.

For gemma4:e4b the case for llama-server is still not throughput - ROCm Ollama on Q4_K_M (54.06 tok/s) is faster than Vulkan llama-bench on UD-Q6_K_XL (43.42 tok/s) - but audio reliability: only llama.cpp exposes the Q6_K quant required for stable audio on clips beyond ~17 seconds, and only llama.cpp has a non-experimental conformer encoder path. The migration remains a config-only change because both backends expose OpenAI-compatible APIs.

---

## 3. llama-server Configuration

### Required Strix Halo flags

The Vulkan service uses `--flash-attn on --load-mode none`. The historical
benchmarks used `-fa 1 --mmap 0` to enable flash attention and disable mmap.

**Revan (RTX 2000e):** uses CUDA, not Vulkan. Standard llama-server flags apply; `--mmap 0` is not required. Flash attention (`-fa 1`) is recommended. The RTX 2000e's 88 Gen 4 Tensor cores accelerate both embedding and small-model inference.

### KV cache quantisation

The model policy sets `--ctx-size` per model and uses
`--cache-type-k q8_0 --cache-type-v q8_0` on all tiers.

llama-server already reuses cached prompt prefixes. Keep the opening tokens
unchanged across requests to the same running backend and model.

### Generation sampler policy

The [model policy](model-policy.nix) sets sampling flags per model. Inkling
uses the [Unsloth local-run settings](https://unsloth.ai/docs/models/inkling-2-mini).
Qwen uses the [model card's thinking-mode settings](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF).
Its default reasoning effort is `medium`. Set `reasoning_effort` in the request
body to override the default.
Gemma uses the [Unsloth Gemma 4 settings](https://unsloth.ai/docs/models/gemma-4)
with thinking enabled. Embedding has no sampler.

### llama-swap as the production model manager

**Decision: llama-swap** (v201, Go binary, https://github.com/mostlygeek/llama-swap) is the production model manager for inference hosts. It runs on each inference host and manages host-local llama-server processes per model. Packaged as a local Nix derivation.

Key features used in this deployment:

- **Per-model `cmd`** - each model gets its own llama-server process with the policy settings and the host's accelerator.
- **On-demand process launch** - llama-swap starts the requested local model when the first matching API call arrives.
- **Separate embedding and generation processes** - embedding models run with `--embedding --pooling last`, while generation models use the normal text-generation path and role-specific sampler settings.
- **`apiKeys`** - optional; useful if llama-swap instances are exposed beyond the Tailscale mesh.

**Native router mode** (llama-server PR #17470, December 2025) was evaluated. It provides auto-discovery and LRU eviction but is marked experimental and does not improve the current split where an autonomous agent chooses the host and host-local llama-swap handles local model launch. Not suitable for the deployment.

### Embedding

llama-swap runs a separate llama-server process on each host for embedding.
The [runtime configuration](runtime.nix) passes `--embedding --pooling last`
explicitly for Qwen3 Embedding.

### Model pre-seeding

The service uses `hf` from the standalone `pkgs.huggingface-cli` package in
unstable to download model files before llama-swap starts:

```bash
hf download --repo-type model --revision <revision> <org/repo> <file-path>
```

The `llama-models-preseed` service uses the dedicated Hugging Face cache at
`/var/lib/llama-models/huggingface`. It removes retired repositories from that
cache only after all selected model files are available.

---

## 4. Hardware and OS Configuration

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

**Registry `vram` field:** Both Strix Halo hosts have `vram = 96` in the registry. With TTM expanded to ~120 GB, effective inference memory is ~112-120 GB. The `vram` registry value represents the conservative inference budget used by the Ollama mixin for model tier selection, not physical memory capacity.

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

## 5. NixOS Configuration

### Hardware mixin snippet

Kernel selection is centralised in `nixos/default.nix`. Hardware-specific module
settings belong in a host-level config or dedicated hardware mixin, not in the
Ollama service mixin:

```nix
{ config, lib, pkgs, ... }:

{
  boot.extraModprobeConfig = ''
    # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
    options ttm pages_limit=31457280
  '';
}
```

### Monitoring

Use `amdgpu_top` v0.11.0 - it introspects all SoC metrics on gfx1151, including GPU clock, utilisation, and power draw.

---

## 6. Gemma media and earlier inference models

### Gemma 4 (Google DeepMind)

Gemma 4 is Google DeepMind's fourth-generation open model family, spanning edge-tier multimodal models to a full 31B dense variant, all with native function calling and configurable thinking mode.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| E2B | 7.2 GB | Dense (2.3B effective) | 128K | Edge-tier, multimodal |
| E4B | 9.6 GB | Dense (4.5B effective) | 128K | Lightweight workhorse, multimodal |
| 26B MoE | 18 GB | MoE, 128 experts, 3.8B active | 256K | Best efficiency/quality ratio |
| 31B | 20 GB | Dense (30.7B) | 256K | Maximum quality, native function calling |

#### Gemma 4 26B MoE

The 26B MoE scores AIME 2026 88.3% versus 89.2% for the 31B dense - a 2% quality trade for meaningfully faster inference. Measured 51.05 tok/s (Vulkan llama-bench) versus the 31B dense at 10.79 tok/s - a 4.7x speed advantage. 256K context window. Native function calling. With 3.8B active parameters (of 128 experts), it is compute-bound on Strix Halo, not memory-bandwidth-ceilinged.

The historical benchmarks put Gemma 26B close to qwen3.5:35b-a3b on throughput
(51 vs 58 tok/s). Neither model is in the current policy.

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

With UD-Q6_K_XL, the backend ranking reverses versus the lighter quant: ROCm Ollama (on Q4_K_M) outperforms Vulkan llama-bench (on UD-Q6_K_XL) for both models - E2B 88.74 vs 82.51, E4B 54.06 vs 43.42. Throughput is traded for audio reliability; the trade is intentional.

Ollama is not a viable production path for audio on these models for two reasons: (1) its audio implementation is experimental and crashes intermittently (issue #15333 - GGML assertion crashes every 2-4 requests on 0.20.2); (2) the default Ollama tag ships Q4_K_M only and does not expose the Q6_K quantisation variants required for reliable audio on longer clips. llama.cpp with UD-Q6_K_XL is the reliable path.

**E2B 5-run means:** ROCm Ollama 88.74 (Q4_K_M), Vulkan Ollama 46.23 (Q4_K_M), ROCm llama-bench 73.42 (UD-Q6_K_XL), Vulkan llama-bench 82.51 (UD-Q6_K_XL).

**E4B 5-run means:** ROCm Ollama 54.06 (Q4_K_M), Vulkan Ollama 26.81 (Q4_K_M), ROCm llama-bench 41.83 (UD-Q6_K_XL), Vulkan llama-bench 43.42 (UD-Q6_K_XL).

Speed on Strix Halo (E4B, production quant UD-Q6_K_XL): ROCm Ollama 54.06 tok/s is the fastest runner but uses the lighter Q4_K_M quant which fails audio beyond ~17s. Vulkan llama-bench reaches 43.42 tok/s on UD-Q6_K_XL - the production audio-capable path. At this size the model is compute-bound, not memory-bandwidth-bound.

### Qwen 3.5 (historical)

Qwen 3.5 is Alibaba's frontier general-purpose model series. The architecture combines Gated Delta Networks with sparse MoE, yielding strong knowledge recall and tool use across a wide size range.

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

## 7. Model Selection: Embedding

Every inference host serves Qwen3 Embedding 0.6B. Revan can handle embedding
requests locally without a network round trip to another inference host.

### qwen3-embedding (Alibaba)

| Variant | Disk (Q4_K_M) | Disk (Q8_0) | Context | Dimensions |
|---|---|---|---|---|
| 0.6B | 639 MB | ~1.2 GB | 32K | Up to 4096 (flexible 32-4096) |
| 4B | 2.5 GB | ~5 GB | 40K | Up to 4096 |
| 8B (latest) | 4.7 GB | ~9 GB | 40K | Up to 4096 |

MTEB multilingual leaderboard #1 (8B variant, score 70.58, June 2025). Code retrieval capable. 100+ languages. The 32K-40K context window can embed entire source files - useful for code-aware memory in autonomous coding agents.

**MTEB benchmarks (retrieval / code retrieval):**

| Variant | MTEB Retrieval | MTEB Code |
|---|---|---|
| 0.6B | baseline | baseline |
| 4B | +4.96 vs 0.6B | +4.65 vs 0.6B |
| 8B | +1.28 vs 4B | +0.62 vs 4B (80.06 vs 80.68) |

The 4B and 8B figures are historical comparisons, not current serving policy.

**Reranker note:** a Qwen3-Reranker-4B on top of qwen3-embedding:0.6B scores 81.20 on MTEB Code, higher than qwen3-embedding:8B alone (80.68). The policy does not configure a reranker.

### Alternatives evaluated and set aside

| Model | Disk | Context | Reason set aside |
|---|---|---|---|
| nomic-embed-text-v2-moe | 958 MB | 512 tokens | Context too short for code chunks |
| embeddinggemma | 622 MB | 2K tokens | No advantage over qwen3-embedding at 2K context |

---

## 8. Recommended Stack

### Architecture: Revan hub with host-local inference launch

```
                    ┌─────────────────────────────┐
                    │          Revan (hub)         │
                    │  i9 9900K · 64 GB · NixOS    │
                    │  RTX 2000e Ada (16 GB, CUDA) │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │  Autonomous agent       │  │
                    │  │  runtime                │  │
                    │  └────────┬────────────────┘  │
                    │           │                    │
                    │  ┌────────▼────────────────┐  │
                    │  │  Request routing         │  │
                    │  │  ├─ host selection       │  │
                    │  │  └─ model selection      │  │
                    │  └────────┬────────────────┘  │
                    │  Jellyfin (NVENC shared)       │
                    └──────────┬──────────┬─────────┘
                     LAN       │          │  Tailscale
                  ┌────────────▼──┐  ┌────▼──────────────┐
                  │ Strix Halo 1  │  │  Strix Halo 2     │
                  │ Home office   │  │  Remote office     │
                  │ (same LAN)    │  │  (Tailscale mesh)  │
                  │               │  │                    │
                  │ llama-swap    │  │  llama-swap        │
                  │ ├ local models│  │  ├ local models    │
                  │ ├ on-demand   │  │  ├ on-demand       │
                  │ └ llama-server│  │  └ llama-server    │
                  │ Vulkan iGPU   │  │  Vulkan iGPU       │
                  └───────────────┘  └────────────────────┘

                  Cloud fallback: OpenCode Zen
                  Frontier: Anthropic Claude
```

**Tailscale mesh:** all three hosts join the same Tailnet via OAuth auto-registration, already configured in the Nix Tailscale module. An autonomous agent can call the chosen inference host directly over Tailscale. The local Strix Halo has sub-millisecond Tailscale overhead, direct WireGuard tunnel on LAN. The remote Strix Halo adds internet-path latency, which is negligible for token-by-token streaming - generation time per token, 14-70ms, dwarfs the network hop.

**What was traded:** the master/padawan warm-standby topology. The agent runtime now runs as a single instance on Revan. If Revan is unavailable, the runtime must be manually deployed to a Strix Halo as a degraded-mode fallback. NixOS declarative config keeps that recovery path fast. Both Strix Halos are now fully utilised for inference instead of one sitting idle as a standby.

### Revan (RTX 2000e, CUDA)

Revan uses the `vram16` tier and serves the same model IDs as the larger hosts.
The smaller quantisations and contexts in the [policy table](#current-model-policy)
apply to Revan. Jellyfin transcoding uses dedicated NVENC/NVDEC hardware on the
same GPU and shares its video memory.


### Cloud and frontier fallback

| Tier | Provider | Model | Trigger |
|---|---|---|---|
| Cloud fallback | OpenCode Zen | `opencode-zen` | Local inference unreachable or model unavailable |
| Frontier | Anthropic | `claude-sonnet-5-5` | Complex reasoning, deep research, tasks exceeding local tier |

An autonomous agent's reliability layer can handle automatic failover: timeout, connection error, 503, or 429 can trigger fallback to the next provider in the chain. Cloud fallback does not require manual intervention.

### Host distribution

Each host exposes its own model IDs through llama-swap. The
[llama-swap module](swap.nix) generates the model commands, including the
context and cache settings from the shared policy. When a model is not
resident, the first request waits for llama-swap to start its process.


**How routing flows in a generic autonomous-agent deployment:**

1. The agent classifies the request by task type.
2. The task hint resolves to a host and model choice.
3. The selected host receives an OpenAI-compatible request for that model.
4. llama-swap on that host starts the matching local llama-server process if it is not already running.
5. If the chosen host is unreachable, the reliability layer retries, then falls back to cloud providers.
6. Embedding requests go directly to the local embedding process on the retrieval host.

### Why autonomous agents need embeddings

An autonomous agent's memory pipeline usually has three stages: hot cache, keyword search, and vector similarity search. Embeddings unlock semantic memory recall, so relevant memories can still be found when the query shares no exact keywords with stored entries. Without embeddings, retrieval falls back to keyword matching only. Any OpenAI-compatible `/embeddings` endpoint can fill this role, so llama-server embedding models fit cleanly into the same serving pattern.

For autonomous agents doing multi-session work - PR reviews that reference earlier discussions, blog drafts that build on prior research - hybrid retrieval is meaningfully better than keyword-only.

### Historical model comparisons

| Model | What the earlier comparison found |
|---|---|
| qwen3.5:122b | 81 GB on disk and about 3.4 tok/s on Strix Halo |
| qwen3.5:27b | 12.10 tok/s on Vulkan llama-bench, without speculative decoding |
| gemma4:31b | 10.79 tok/s on Vulkan llama-bench, versus 51.05 tok/s for gemma4:26b |
| qwen3-coder:30b | 50.3% on SWE-Bench, versus 70.6% for qwen3-coder-next |

---


## 9. NPU: Future Consideration

The Ryzen AI Max+ 395 includes 40 XDNA2 neural processing units - dedicated silicon for matrix operations, separate from the iGPU.

**Current state (April 2026):**

- **llama.cpp:** no upstream NPU backend. A community fork by BrandedTamarasu-glitch (March 2026) dispatches GEMM ops via `mlir-aie` xclbins and XRT 2.21.75, achieving 43.7 tok/s on Llama-3.1-8B Q4_K_M at 0.947 J/tok - matching Vulkan iGPU decode speed while drawing ~10 W less. Not merged upstream.
- **Ollama:** no NPU support. Two open feature requests (issues #5186 and #11199) with 100+ upvotes each, no roadmap.
- **Linux driver:** `amdxdna` landed in kernel 6.14 (mainline). Userspace requires XRT + xrt-plugin-amdxdna shim; custom NixOS packaging would be needed.

**Why not now:** the NPU and iGPU share the LPDDR5X memory bus. For large memory-bound models, neither can exceed the bus throughput - the NPU cannot outperform what Vulkan iGPU already delivers.

**Why it matters later:** the NPU and iGPU are separate compute units. A future
NPU backend can let the NPU serve embeddings while the iGPU handles generation.

**Trigger to revisit:** `ggml-hsa` merging into llama.cpp upstream, or llama-server gaining explicit NPU backend support.

---

## 10. References

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
| llama-swap (v201) | https://github.com/mostlygeek/llama-swap |
| llama-swap configuration docs | https://github.com/mostlygeek/llama-swap/blob/main/docs/configuration.md |
| nixpkgs PR #488117 - llama-cpp hfRepo/hfFile | https://github.com/NixOS/nixpkgs/pull/488117 |
| PNY RTX 2000e Ada Generation | https://www.pny.com/rtx-2000e-ada-generation |
| Tailscale performance best practices | https://tailscale.com/docs/reference/best-practices/performance |
| Level1Techs Strix Halo LLM benchmarks | https://forum.level1techs.com/t/strix-halo-ryzen-ai-max-395-llm-benchmark-results/233796 |
