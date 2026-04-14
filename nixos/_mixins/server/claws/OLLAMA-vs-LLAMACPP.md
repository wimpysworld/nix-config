# Ollama vs llama.cpp on Strix Halo

> AMD Ryzen AI Max+ 395 (gfx1151, RDNA3.5) · 128 GB LPDDR5X · Framework Desktop mainboard · NixOS 25.11 · Linux 6.19.11 · Ollama 0.20.6 · llama.cpp b8775 · ROCm 7.2.1 · linux-firmware 20260309
> Benchmarks cover the two Strix Halo inference hosts. In production these hosts serve inference over Tailscale to the Revan hub, which runs ZeroClaw, embedding, and a small local model on an RTX 2000e Ada.

---

## 1. Hardware Context

**Strix Halo inference hosts (×2):** AMD Ryzen AI Max+ 395, 128 GB unified LPDDR5X, ~270 GB/s peak / ~212 GB/s practical memory bandwidth. One host is on the same LAN as Revan; the other is at a remote site, reachable over Tailscale.

**Practical memory budget:** reserve ~56 GB for NixOS, desktop, and dev tools, leaving ~72 GB for inference. With llama-swap `groups` and `persistent: true`, multiple models stay loaded simultaneously - no hot-swap delay for production models.

**Revan hub:** Intel i9 9900K (downclocked, 65W), 64 GB RAM, NixOS. Houses an NVIDIA RTX 2000e Ada Generation (16 GB GDDR6 ECC, 50W bus-powered, Ada Lovelace, CUDA) for embedding, re-ranking, a small local model, and Jellyfin NVENC. ZeroClaw runs in a systemd-nspawn container on Revan and connects to the local llama-swap instance, which routes inference requests to the Strix Halo hosts via `peers`.

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

## 3. Ollama Configuration (Transitional)

Ollama is superseded by llama-server/llama-swap for production inference. This section is retained for reference during the transition period and for any hosts that still use Ollama for model downloads.

### Vulkan backend

Use `pkgs.ollama-vulkan`. The existing Ollama mixin selects this automatically when `host.gpu.compute.acceleration = "vulkan"`. Both Strix Halo hosts have `acceleration = "vulkan"` in the registry.

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

**Revan (RTX 2000e):** uses CUDA, not Vulkan. Standard llama-server flags apply; `--mmap 0` is not required. Flash attention (`-fa 1`) is recommended. The RTX 2000e's 88 Gen 4 Tensor cores accelerate both embedding and small-model inference.

### KV cache quantisation

This deployment now standardises on quantised KV cache for all policy-selected models. The shared Nix model policy carries the KV decision per role entry and emits `--cache-type-k q8_0 --cache-type-v q8_0` alongside the context window for each selected model.

The earlier Strix Halo benchmark note still holds for shorter contexts: `q8_0` KV cache costs some throughput. That is no longer the optimisation target. The policy goal is to expose the full available context on the selected models, which shifts the trade-off decisively towards KV compression. In practice:

- `q8_0/q8_0` is the default across all current VRAM tiers and model roles.
- `--ctx-size` is set from the model policy, not hard-coded per host.
- KV cache policy now follows model capability and role, not a single blanket host default.

The current policy lives in `nixos/_mixins/server/llama-server/model-policy.nix`.

### Generation sampler policy

The shared model policy now carries generation settings as well as context and KV cache settings. Where present, the policy emits the corresponding `llama-server` flags from the role entry itself rather than relying on hand-written per-host defaults.

The encoded fields are:

- `temperature`
- `top_p`
- `top_k`
- `repetition_penalty`
- optional `min_p`
- optional `presence_penalty`

The settings were not guessed ad hoc. They were lifted from primary-source Unsloth local-run guidance for the same model family, then attached to the relevant policy role. The decision rule is:

- use Unsloth's published local-run defaults when an exact family page exists
- store them per role entry, not once per VRAM tier, because role intent matters
- leave the generation block unset when no equivalent primary-source page exists
- omit generation settings from embedding entries

Current source set:

- `Qwen3-Coder-30B-A3B-Instruct`: https://unsloth.ai/docs/models/tutorials/qwen3-coder-how-to-run-locally
- `Qwen3-Coder-Next`: https://unsloth.ai/docs/models/qwen3-coder-next
- `Qwen3.5`: https://unsloth.ai/docs/models/qwen3.5
- `Gemma 4`: https://unsloth.ai/docs/models/gemma-4
- `gpt-oss`: https://unsloth.ai/docs/models/gpt-oss-how-to-run-and-fine-tune

Models deliberately left unset in the live policy:

- `Qwen2.5-Coder-14B-Instruct-128K`
- `Qwen2.5-Coder-7B-Instruct-128K`
- `rnj-1-instruct`
- both `Qwen3-Embedding` variants

The reasoning is different for each group:

- `Qwen2.5-Coder-*` has no matching Unsloth local-run page in the current docs set, so copying `Qwen3-Coder` values would be invented policy.
- `rnj-1-instruct` now uses Unsloth's GGUF requant, but Unsloth does not publish a comparable local-run sampler page for it. The Hugging Face card gives a temperature range, but not a full sampler profile. The policy therefore keeps `rnj-1` unset rather than mixing sources.
- embedding models do not use text-generation sampling controls in the same way, so they do not belong in the generation block.

The `gpt-oss` case has one extra nuance. Unsloth treats `reasoning_effort` as a first-class control, but that is not yet represented in the Nix model policy because it is a Harmony-level behaviour setting rather than a plain llama.cpp sampler flag. The current policy therefore records the source-backed sampler defaults for `gpt-oss` and leaves `reasoning_effort` for a later dedicated wiring pass.

### llama-swap as the production model manager

**Decision: llama-swap** (v201, Go binary, https://github.com/mostlygeek/llama-swap) is the production model manager for all hosts. It runs on each of the three hosts (Revan + two Strix Halos) and manages llama-server processes per model. Packaged as a local Nix derivation.

Key features used in this deployment:

- **`groups` with `persistent: true`** - embedding and small models on Revan stay resident permanently; inference models on Strix Halos stay loaded without TTL-based eviction.
- **`peers`** - Revan's llama-swap routes inference requests to the Strix Halo llama-swap instances over Tailscale. Each peer declares which models it serves.
- **`v1/embeddings` and `v1/rerank` routing** - embedding and re-ranking requests stay local to Revan's RTX 2000e; generation requests route to peers.
- **Per-model `cmd`** - each model gets its own llama-server process with appropriate flags (Vulkan + `--mmap 0` on Strix Halo, CUDA on Revan).
- **`apiKeys`** - optional; useful if llama-swap instances are exposed beyond the Tailscale mesh.

**Native router mode** (llama-server PR #17470, December 2025) was evaluated. It provides auto-discovery and LRU eviction but is marked experimental and lacks the `peers` feature, persistent groups, and mixed generation/embedding handling that llama-swap provides. Not suitable for the distributed topology.

### Embedding and re-ranking

Embedding and re-ranking run on Revan's RTX 2000e, co-located with ZeroClaw for zero-network-hop retrieval.

`llama-server` in `--embedding` mode locks the server to embeddings only. llama-swap handles this naturally - it runs a dedicated llama-server process for the embedding model and a separate one for re-ranking, each in its own always-on group. No manual process management required.

One operational requirement for Qwen3-Embedding models: `--pooling last` must be passed explicitly at startup - the GGUF metadata does not carry this flag, so omitting it produces incorrect embeddings.

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

The NixOS pattern is a systemd oneshot service that runs the downloads before `llama-swap` starts, with models stored under `/var/lib/llama-models/`. This applies to all three hosts: Revan pre-seeds embedding and small models; each Strix Halo pre-seeds its assigned inference models. nixpkgs PR #488117 adds `hfRepo`/`hfFile` options directly to `services.llama-cpp` with download at service start, but it has not yet merged. Until it does, the download oneshot must be written by hand.

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

#### Gemma 4 26B MoE

The 26B MoE scores AIME 2026 88.3% versus 89.2% for the 31B dense - a 2% quality trade for meaningfully faster inference. Measured 50.30 tok/s (Vulkan llama-bench) versus the 31B dense at 10.68 tok/s - a 4.7x speed advantage. 256K context window. Native function calling. With 3.8B active parameters (of 128 experts), it is compute-bound on Strix Halo, not memory-bandwidth-ceilinged.

The 26B MoE occupies a distinct niche from qwen3.5:35b-a3b: comparable throughput (50 vs 58 tok/s) but from the Gemma family, with Google's function-calling conventions and a different training distribution. Useful as an alternative general-purpose model and for workloads where Gemma-family behaviour is preferred.

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

Embedding runs on Revan's RTX 2000e (CUDA), co-located with ZeroClaw. This eliminates network round-trips for RAG embedding and retrieval - the embedding model is local to ZeroClaw's data store.

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

**Quantisation:** embedding quality degrades more with aggressive quantisation than generation quality does. On the RTX 2000e (16 GB VRAM), use Q8_0: the ~5 GB memory cost is trivial alongside the small model and re-ranker, with ~10 GB headroom remaining.

**Context window:** the official Ollama Modelfile for `qwen3-embedding:4b-q8_0` sets `num_ctx` to the model's full 40,960-token native context. The equivalent llama-server flag is `--ctx-size 40960`.

**Reranker note:** a Qwen3-Reranker-4B on top of qwen3-embedding:0.6B scores 81.20 on MTEB Code, higher than qwen3-embedding:8B alone (80.68). Planned as a future enhancement on Revan - the RTX 2000e has ample VRAM to run both the embedding model and a re-ranker concurrently.

### Alternatives evaluated and set aside

| Model | Disk | Context | Reason set aside |
|---|---|---|---|
| nomic-embed-text-v2-moe | 958 MB | 512 tokens | Context too short for code chunks |
| embeddinggemma | 622 MB | 2K tokens | No advantage over qwen3-embedding at 2K context |

---

## 9. Recommended Stack

### Architecture: Revan hub with distributed Strix Halo inference

```
                    ┌─────────────────────────────┐
                    │          Revan (hub)         │
                    │  i9 9900K · 64 GB · NixOS    │
                    │  RTX 2000e Ada (16 GB, CUDA) │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │  ZeroClaw (nspawn)       │  │
                    │  │  Darth Traya             │  │
                    │  └────────┬────────────────┘  │
                    │           │                    │
                    │  ┌────────▼────────────────┐  │
                    │  │  llama-swap (host)       │  │
                    │  │  ├─ qwen3-embedding-4b   │  │
                    │  │  ├─ qwen3.5-9b (agentic) │  │
                    │  │  └─ peers:               │  │
                    │  │     ├─ strix-halo-1 (TS) │  │
                    │  │     └─ strix-halo-2 (TS) │  │
                    │  └─────────────────────────┘  │
                    │  Jellyfin (NVENC shared)       │
                    └──────────┬──────────┬─────────┘
                     LAN       │          │  Tailscale
                  ┌────────────▼──┐  ┌────▼──────────────┐
                  │ Strix Halo 1  │  │  Strix Halo 2     │
                  │ Home office   │  │  Remote office     │
                  │ (same LAN)    │  │  (Tailscale mesh)  │
                  │               │  │                    │
                  │ llama-swap    │  │  llama-swap        │
                  │ ├ qwen3.5:    │  │  ├ qwen3-coder-   │
                  │ │ 35b-a3b     │  │  │ next            │
                  │ ├ gemma4:26b  │  │  ├ qwen3.5:        │
                  │ └ gemma4:e4b  │  │  │ 35b-a3b         │
                  │               │  │  └ (headroom)      │
                  │ Vulkan iGPU   │  │  Vulkan iGPU       │
                  └───────────────┘  └────────────────────┘

                  Cloud fallback: OpenCode Zen
                  Frontier: Anthropic Claude (via ZeroClaw routing)
```

**Tailscale mesh:** all three hosts join the same Tailnet via OAuth auto-registration (already configured in the Nix Tailscale module). Revan's llama-swap uses Tailscale IPs for the Strix Halo peers. The local Strix Halo has sub-millisecond Tailscale overhead (direct WireGuard tunnel on LAN). The remote Strix Halo adds internet-path latency, which is negligible for token-by-token streaming - generation time per token (14-70ms) dwarfs the network hop.

**What was traded:** the master/padawan warm-standby topology. ZeroClaw now runs as a single instance on Revan. If Revan is unavailable, ZeroClaw must be manually deployed to a Strix Halo as a degraded-mode fallback. NixOS declarative config makes this fast - the same nspawn module applies on any host. Both Strix Halos are now fully utilised for inference instead of one sitting idle as a standby.

### Revan model table (RTX 2000e, CUDA)

| Slot | Model | Disk | Context | VRAM est. | Primary use |
|---|---|---|---|---|---|
| Embedding | qwen3-embedding:4b-q8_0 | ~5 GB | 40K | ~5 GB | Memory retrieval |
| Simple tasks | qwen3:1.7b | ~1.5 GB | 32K | ~1.5 GB | Classification, formatting, quick completions |
| Reranking (future) | qwen3-reranker:4b | ~5 GB | - | ~5 GB | Retrieval quality boost |
| **Jellyfin** | NVENC/NVDEC | - | - | ~0.5 GB/stream | Hardware transcoding (AV1 encode/decode) |
| **Total (current)** | | **~6.5 GB** | | **~7 GB** | **~9 GB headroom in 16 GB** |

NVENC/NVDEC use dedicated fixed-function silicon separate from CUDA and Tensor cores. Jellyfin transcoding and llama.cpp inference coexist without compute contention; they share only VRAM bandwidth.

### Shared Nix model policy

The live deployment no longer uses one fixed Strix Halo model set. Model selection is derived from `nixos/_mixins/server/llama-server/model-policy.nix`, keyed by available VRAM. The role split is now:

- `coding`
- `agentic`
- `reasoning`
- `smallMedia`
- `embedding`

Current policy matrix:

| VRAM tier | Coding | Agentic | Reasoning | Small / media | Embedding |
|---|---|---|---|---|---|
| `vram64` | qwen3-coder-next | qwen3.5:35b-a3b | gemma4:26b | gemma4:e4b | qwen3-embedding:4b-q8_0 |
| `vram32` | qwen3-coder:30b-a3b | qwen3.5:35b-a3b | gemma4:26b | gemma4:e4b | qwen3-embedding:4b-q8_0 |
| `vram22` | qwen3-coder:30b-a3b | qwen3.5:35b-a3b | gemma4:26b | gemma4:e4b | qwen3-embedding:4b-q8_0 |
| `vram16` | qwen2.5-coder:14b | qwen3.5:9b | gpt-oss:20b | gemma4:e4b | qwen3-embedding:4b-q8_0 |
| `vram8` | qwen2.5-coder:7b | rnj-1:8b | qwen3.5:9b | gemma4:e2b | qwen3-embedding:0.6b-q8_0 |

Generation settings are also policy-driven. At the time of writing, the live policy encodes Unsloth-backed sampler defaults for `Qwen3-Coder-Next`, `Qwen3-Coder-30B-A3B`, `Qwen3.5`, `Gemma 4`, and `gpt-oss`. It intentionally leaves `Qwen2.5-Coder-*`, `rnj-1`, and both embedding models without a `generation` block until there is a matching primary-source recommendation.

### Current model table

| Role | Model | Context | tok/s | Primary use |
|---|---|---|---|---|
| Coding | qwen3-coder-next | 256K | 44.77 | Primary coding model on the biggest tier, optimised for agentic coding loops |
| Coding | qwen3-coder:30b-a3b | 256K | - | Coding model for 22 GB and 32 GB tiers |
| Coding | qwen2.5-coder:14b | 128K | - | Coding model for 16 GB tiers |
| Coding | qwen2.5-coder:7b | 128K | - | Coding model for 8 GB tiers |
| Agentic | qwen3.5:35b-a3b | 256K | 57.72 | Structured output, tool use, broad local agent loops |
| Agentic | qwen3.5:9b | 256K | 36.25 | Lightweight local agentic fallback on 16 GB and 8 GB tiers |
| Agentic | rnj-1:8b | 32K | - | Text-first lightweight agentic model for the 8 GB tier |
| Reasoning | gemma4:26b | 256K | 50.30 | Gemma-family reasoning and fallback target on large tiers |
| Reasoning | gpt-oss:20b | 128K | 82.99 | Fast reasoning model for the 16 GB tier |
| Small / media | gemma4:e4b | 128K | 42.93§ | Audio, vision, summarisation, fast triage |
| Small / media | gemma4:e2b | 128K | - | Reduced-footprint media model for the 8 GB tier |
| Embedding | qwen3-embedding:4b-q8_0 | 40K | - | Primary embedding model on 16 GB and above |
| Embedding | qwen3-embedding:0.6b-q8_0 | 32K | - | Embedding fallback for the 8 GB tier |

§ gemma4:e4b tok/s is Vulkan llama-bench on UD-Q6_K_XL - the production quant for audio reliability.

### Cloud and frontier fallback

| Tier | Provider | Model | Trigger |
|---|---|---|---|
| Cloud fallback | OpenCode Zen | `opencode-zen` | Local inference unreachable or model unavailable |
| Frontier | Anthropic | `claude-sonnet-4-6` | Complex reasoning, deep research, tasks exceeding local tier |

ZeroClaw's `[reliability]` section handles automatic failover: timeout, connection error, 503, or 429 (after API key rotation) triggers fallback to the next provider in the chain. Cloud fallback does not require manual intervention.

### Host distribution

Host distribution is now policy-driven rather than documented as a fixed hand-maintained model list. Each inference host selects its local model set from the shared VRAM matrix. Operationally:

- Revan prioritises embedding and small local fallback work on the RTX 2000e.
- Larger inference hosts expose the full `coding`, `agentic`, `reasoning`, and `smallMedia` role set that their VRAM tier allows.
- The exact per-host model list is derived from `model-policy.nix`, so the Nix policy is the source of truth.

All models are configured in llama-swap `groups` with `persistent: true` and `swap: false` so they remain loaded at all times. No cold-start delay.

### llama-swap configuration

**Revan** (`/etc/llama-swap/config.yaml`):

```yaml
models:
  qwen3-embedding-4b:
    cmd: >
      llama-server --port ${PORT}
      --model /var/lib/llama-models/qwen3-embedding-4b-q8_0.gguf
      --embedding --pooling last --ctx-size 40960
      --cache-type-k q8_0 --cache-type-v q8_0 -fa 1
  qwen3.5-9b:
    cmd: >
      llama-server --port ${PORT}
      --model /var/lib/llama-models/qwen3.5-9b.gguf
      --ctx-size 262144
      --cache-type-k q8_0 --cache-type-v q8_0 -fa 1

groups:
  always-on:
    swap: false
    exclusive: false
    persistent: true
    members:
      - qwen3-embedding-4b
      - qwen3.5-9b

peers:
  strix-halo-1:
    proxy: http://<strix-halo-1-ts-ip>:8080
    models:
      - qwen3.5-35b-a3b
      - gemma4-26b
      - gemma4-e4b
  strix-halo-2:
    proxy: http://<strix-halo-2-ts-ip>:8080
    models:
      - qwen3-coder-30b-a3b
      - qwen3.5-35b-a3b
```

**Each Strix Halo** (example for Strix Halo 1):

```yaml
models:
  qwen3.5-35b-a3b:
    cmd: >
      llama-server --port ${PORT}
      --model /var/lib/llama-models/qwen3.5-35b-a3b.gguf
      --ctx-size 262144
      --cache-type-k q8_0 --cache-type-v q8_0 -fa 1 --mmap 0
  gemma4-26b:
    cmd: >
      llama-server --port ${PORT}
      --model /var/lib/llama-models/gemma4-26b.gguf
      --ctx-size 262144
      --cache-type-k q8_0 --cache-type-v q8_0 -fa 1 --mmap 0
  gemma4-e4b:
    cmd: >
      llama-server --port ${PORT}
      --model /var/lib/llama-models/gemma4-e4b-q6k.gguf
      --ctx-size 131072
      --cache-type-k q8_0 --cache-type-v q8_0 -fa 1 --mmap 0

groups:
  always-on:
    swap: false
    exclusive: false
    persistent: true
    members:
      - qwen3.5-35b-a3b
      - gemma4-26b
      - gemma4-e4b
```

These examples are illustrative. The live Nix policy now generates `--ctx-size`, `--cache-type-k`, and `--cache-type-v` from the shared role definition rather than hard-coding them in per-host notes.

### ZeroClaw configuration

ZeroClaw connects to a single endpoint: Revan's local llama-swap instance. llama-swap handles routing to local models (embedding, small) and remote peers (Strix Halo inference). ZeroClaw uses `[[model_routes]]` hints to select models by task type and `[query_classification]` for automatic routing.

Configuration pattern (`~/.zeroclaw/config.toml`):

```toml
# --- Provider and default model ---
default_provider = "custom:http://<host-container-ip>:8080/v1"
default_model = "hint:agentic"

# --- Model routes (hint-based task dispatch) ---
[[model_routes]]
hint = "code"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3-coder-30b-a3b"

[[model_routes]]
hint = "agentic"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3.5-35b-a3b"

[[model_routes]]
hint = "reasoning"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "gemma4-26b"

[[model_routes]]
hint = "media"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "gemma4-e4b"

[[model_routes]]
hint = "cloud"
provider = "opencode"
model = "opencode-zen"

[[model_routes]]
hint = "frontier"
provider = "anthropic"
model = "claude-sonnet-4-6"

# --- Embedding routes ---
[memory]
backend = "sqlite"
embedding_model = "hint:local-embed"

[[embedding_routes]]
hint = "local-embed"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3-embedding-4b"
dimensions = 4096

# --- Query classification (automatic hint routing) ---
[query_classification]
enabled = true

[[query_classification.rules]]
hint = "code"
patterns = ["```", "fn ", "def ", "func ", "class "]
priority = 10

[[query_classification.rules]]
hint = "reasoning"
keywords = ["explain", "analyze", "research", "compare", "write", "draft"]
min_length = 100
priority = 5

# --- Reliability and fallback ---
[reliability]
fallback_providers = ["opencode", "anthropic"]
provider_retries = 2
provider_backoff_ms = 500

[reliability.model_fallbacks]
"qwen3-coder-30b-a3b" = ["qwen3.5-35b-a3b"]
"qwen3.5-35b-a3b" = ["gemma4-26b"]
"gemma4-26b" = ["qwen3.5-35b-a3b"]

# --- Pacing for local inference ---
[pacing]
step_timeout_secs = 120
```

**How routing flows:**

1. User sends a message via Telegram.
2. ZeroClaw's `[query_classification]` matches the message against rules and selects a hint (e.g. `hint:code` for messages containing code fences).
3. The hint resolves to a `[[model_routes]]` entry - e.g. `hint:code` → `qwen3-coder-30b-a3b` via the local llama-swap endpoint.
4. llama-swap on Revan sees the `model: "qwen3-coder-30b-a3b"` request and routes it to the appropriate peer via the `peers` config.
5. If Strix Halo 2 is unreachable, ZeroClaw's `[reliability]` chain retries, then falls back to `opencode` (OpenCode Zen), then `anthropic` (Claude).
6. Embedding requests (`v1/embeddings` with `model: "qwen3-embedding-4b"`) stay local to Revan - no peer routing, no network hop.

### Rationale per slot

**qwen3-coder-next as top-tier coding primary:** 80B total / 3B active MoE. It remains the best coding fit on the biggest tier, especially for agentic retry loops and repository-scale work.

**qwen3-coder:30b-a3b as mid-tier coding primary:** the policy now uses it for the 22 GB and 32 GB tiers. It keeps a coding-specialised model in those slots instead of reusing the broader agentic model.

**qwen3.5:35b-a3b as agentic primary:** 3.3B active MoE, 256K context. Measured 57.72 tok/s (Vulkan llama-bench). This is the broad local agentic model for larger tiers, replacing the earlier looser `general` label.

**qwen3.5:9b and rnj-1 as lightweight agentic models:** the smaller tiers no longer mirror the large-tier mix. `qwen3.5:9b` is the local agentic fallback on 16 GB hosts. `rnj-1:8b` is the narrower text-first agentic choice on the 8 GB tier.

**gemma4:26b as reasoning primary on larger tiers:** 3.8B active MoE, 256K context. Measured 50.30 tok/s (Vulkan llama-bench). It occupies the reasoning slot where Gemma-family behaviour and function calling are preferred.

**gpt-oss:20b as reasoning model for 16 GB:** measured 82.99 tok/s in the local Vulkan benchmark set. It is the current reasoning pick on the 16 GB tier because it offers strong local reasoning throughput at a manageable footprint.

**gemma4:e4b as small/media model:** the only local model in the stack with audio and video capability - neither of the larger Gemma 4 models has an audio encoder. Image and video (frame sequences up to 60 seconds) work today. Audio transcription and understanding are model-supported but pending llama.cpp and Ollama implementation; use Q6_K when audio lands. At ~5 GB and 42.93 tok/s (Vulkan llama-bench, 5-run mean, UD-Q6_K_XL - the production quant required for audio reliability) it handles summarisation, fast triage, and lightweight tasks without loading a larger model.

**qwen3-embedding:4b-q8_0 as embedding primary:** load permanently in llama-swap's `always-on` group. The 4B sits at the quality optimum: +4.96 MTEB retrieval and +4.65 MTEB Code over the 0.6B, with the 8B adding only 0.62 further points at half the throughput. Q8_0 preserves embedding fidelity that Q4_K_M would compromise; the ~5 GB VRAM cost is trivial on the RTX 2000e's 16 GB. The current policy uses its full 40K context.

**qwen3-embedding:0.6b-q8_0 as embedding fallback:** retained for the 8 GB tier where the 4B model is too large a permanent fit.

**OpenCode Zen as cloud fallback:** activated automatically by ZeroClaw's `[reliability]` chain when local inference is unreachable. ZeroClaw has native `opencode` provider support.

**Frontier (Claude):** local models handle the 80-90% routine case; Claude handles deep research and complex multi-step reasoning that exceeds the local tier.

### Why ZeroClaw needs embeddings

ZeroClaw's memory pipeline has three stages: hot cache, FTS5 keyword search, and vector similarity search. Embeddings unlock stage 3 - semantic memory recall finds relevant memories even when the query shares no exact keywords with stored entries. Without embeddings, ZeroClaw falls back to `NoopEmbedding`, which returns empty vectors and limits retrieval to keyword matching only. The `EmbeddingProvider` trait uses any OpenAI-compatible `/embeddings` endpoint, so llama-server embedding models work natively. ZeroClaw's `[[embedding_routes]]` with `hint:` patterns route embedding requests to the correct provider.

For agents doing multi-session agentic work - PR reviews that reference earlier discussions, blog drafts that build on prior research - hybrid retrieval is meaningfully better than keyword-only.

### Models evaluated and set aside

| Model | Reason |
|---|---|
| qwen3.5:122b | 81 GB leaves ~29 GB for NixOS + desktop + context; ~3.4 tok/s impractical for interactive work |
| qwen3.5:27b | Dense 27B; measured 12.10 tok/s (Vulkan llama-bench) - bandwidth-ceilinged regardless of backend. qwen3-coder-next provides 3.7x throughput at comparable SWE-Bench quality (70.6% vs 72.4%). |
| gemma4:31b | Dense 30.7B; measured 10.68 tok/s (Vulkan llama-bench) - same bandwidth ceiling as qwen3.5:27b. gemma4:26b MoE delivers 50.30 tok/s at near-identical quality. |
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

**Why it matters later:** the NPU and iGPU are separate compute units. Once tooling matures, both can run concurrently - the NPU serving the embedding model while the iGPU handles generation, eliminating the current serialisation where embedding requests stall generation. In the current architecture, embedding is offloaded to Revan's RTX 2000e, so this is less pressing - but NPU co-processing could increase per-host inference throughput if more models are loaded.

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
| llama-swap (v201) | https://github.com/mostlygeek/llama-swap |
| llama-swap configuration docs | https://github.com/mostlygeek/llama-swap/blob/main/docs/configuration.md |
| nixpkgs PR #488117 - llama-cpp hfRepo/hfFile | https://github.com/NixOS/nixpkgs/pull/488117 |
| PNY RTX 2000e Ada Generation | https://www.pny.com/rtx-2000e-ada-generation |
| ZeroClaw providers reference | https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/reference/api/providers-reference.md |
| Tailscale performance best practices | https://tailscale.com/docs/reference/best-practices/performance |
| Level1Techs Strix Halo LLM benchmarks | https://forum.level1techs.com/t/strix-halo-ryzen-ai-max-395-llm-benchmark-results/233796 |
