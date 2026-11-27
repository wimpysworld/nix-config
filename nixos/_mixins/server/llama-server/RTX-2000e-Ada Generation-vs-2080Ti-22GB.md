# RTX 2000e Ada Generation versus 2080 Ti 22GB: Revan GPU comparison

## Hardware benchmark comparison

The `llama.cpp` CUDA scoreboard provides direct, comparable benchmarks on a standard workload (Llama 2 7B `Q4_0`) for both cards.

| Metric | RTX 2000e Ada | RTX 2080 Ti (stock 11GB) | 2080 Ti advantage |
|---|---:|---:|---:|
| `pp512` (no flash attention) | 1,956 tok/s | 2,891 tok/s | +48% |
| `pp512` (flash attention) | 2,250 tok/s | 3,108 tok/s | +38% |
| `tg128` (no flash attention) | 50.62 tok/s | 107.51 tok/s | +112% |
| `tg128` (flash attention) | 50.71 tok/s | 109.17 tok/s | +115% |

The 2080 Ti generates tokens 2.15x faster and processes prompts 1.4x faster on this reference workload. Memory bandwidth drives the gap: 616 GB/s on a 352-bit bus versus 224 GB/s on a 128-bit bus. The 22GB VRAM mod replaces each 1GB GDDR6 chip with a 2GB chip on the same bus, so it doubles capacity without changing bandwidth.

## Full specification comparison

| Specification | RTX 2000e Ada | RTX 2080 Ti (22GB mod) | Notes |
|---|---|---|---|
| Architecture | Ada Lovelace (AD107) | Turing (TU102) | Two generations apart |
| Compute capability | 8.9 | 7.5 | Ada adds FP8 and BF16 support |
| CUDA cores | 2,816 | 4,352 | 2080 Ti has 1.55x more cores |
| Tensor cores | 88 (Gen 4) | 544 (Gen 2) | Gen 4 adds FP8, Gen 2 is FP16 only |
| VRAM | 16 GB GDDR6 ECC | 22 GB GDDR6 (modded) | 2080 Ti has 37% more VRAM |
| Memory bus | 128-bit | 352-bit | 2.75x wider bus |
| Memory bandwidth | 224 GB/s | 616 GB/s | 2.75x higher bandwidth |
| TDP | 50W (bus-powered) | 250W (2x 8-pin PCIe) | 5x peak power draw |
| Form factor | Single-slot, half-height | 2-slot, full-height | Both fit Revan's slot |
| PCIe power | None (bus-powered) | 2x 8-pin required | Needs PSU cables |
| NVENC | 7th gen (AV1 encode and decode) | 6th gen (no AV1 encode) | Ada adds AV1 |
| NVDEC | 5th gen (AV1 decode) | 3rd gen (no AV1 decode) | Ada adds AV1 decode |
| FP32 TFLOPS | 8.9 | ~13.4 | 2080 Ti has 1.5x raw compute |
| Tensor TOPS (INT8) | 71 | N/A (Gen 2 is FP16 only) | Ada wins on INT8 hardware support |

## The 22GB VRAM mod

The mod replaces the eleven 1GB (8 Gbit) GDDR6 chips on the PCB with 2GB (16 Gbit) chips of the same speed grade. Capacity doubles from 11 GB to 22 GB, while memory clock, bus width, bandwidth, and compute performance stay unchanged. Mods using 16 Gbit Samsung or Micron K4ZAF325BM chips are reported stable, and the hardware modification is irreversible.

## Impact on Revan's workloads

### Embeddings

Both GPUs handle local embeddings easily. [model-policy.nix](model-policy.nix) serves `qwen3-embedding-0.6b` (`Q8_0`, 8K context, ~0.9 GiB) on every tier with no reranker configured, and `llama-swap` keeps it resident on Revan for Silo recommendations and local API requests. Higher memory bandwidth processes embedding batches faster, but embedding throughput is not a bottleneck on Revan.

### Local generation models (`vram16` versus `vram22`)

Revan's 16 GB RTX 2000e Ada selects the `vram16` policy tier, while a 22 GB card unlocks the `vram22` tier (the same tier that `maul` uses with its 24 GB NVIDIA GPU):

| Role | `vram16` (RTX 2000e Ada) | `vram22` (RTX 2080 Ti 22GB) |
|---|---|---|
| `moe` | `mellum2.1-12b` (text-only), `Q6_K`, 128K (~13.0 GiB) | `mellum2.1-12b` (text-only), `Q8_0`, 128K (~14.9 GiB) |
| `dense` (vision) | `qwen3.5-9b`, `UD-Q4_K_XL`, 128K, `reasoning off` (~10.7 GiB, `mmproj-BF16.gguf`) | `qwen3.5-9b`, `UD-Q4_K_XL`, 256K, `reasoning off` (~12.8 GiB, `mmproj-BF16.gguf`) |
| `embedding` | `qwen3-embedding-0.6b`, `Q8_0`, 8K (~0.9 GiB) | `qwen3-embedding-0.6b`, `Q8_0`, 8K (~0.9 GiB) |

`llama-swap` keeps `qwen3-embedding-0.6b` resident and loads one generation model at a time on demand. Upgrading to `vram22` raises `mellum2.1-12b` from `Q6_K` to `Q8_0` at its native 128K context ceiling, doubles `qwen3.5-9b` context from 128K to 256K, and uses the 2080 Ti's 2.75x wider memory bus for faster CUDA token generation. No benchmark covers the current `mellum2.1-12b` or `qwen3.5-9b` weights on either card, so the Llama 2 7B scoreboard above remains the measured hardware baseline.

### Hardware media transcoding

The 2080 Ti uses 6th-generation NVENC and 3rd-generation NVDEC, so it lacks AV1 encode and decode. H.264 and H.265 transcoding still work. For Silo (and Jellyfin-compatible) transcoding on Revan, the RTX 2000e's 7th-generation NVENC and 5th-generation NVDEC are materially better for AV1 media and roughly comparable on H.264 and H.265.

### Power and thermals

Power draw is the main operational trade-off for an always-on server. The RTX 2000e draws at most 50W from the PCIe slot with low heat and noise. The 2080 Ti draws up to 250W under sustained inference load, requires two 8-pin PCIe power cables, and adds heat and fan noise. At idle the 2080 Ti drops to roughly 20W to 30W, while active inference draws roughly 150W to 200W.

Assuming 4 hours of active inference and 20 hours idle per day:

- **RTX 2000e Ada:** ~50W x 4h + ~10W x 20h = 400 Wh/day (~146 kWh/year)
- **RTX 2080 Ti 22GB:** ~200W x 4h + ~25W x 20h = 1,300 Wh/day (~475 kWh/year)

At UK electricity rates (~28p/kWh), that is roughly GBP 42/year versus GBP 133/year, a GBP 91 annual difference.

## Pros and cons summary

### RTX 2000e Ada (current)

| Pros | Cons |
|---|---|
| 50W bus-powered, no PSU cables, quiet operation | 128-bit bus limits bandwidth-bound token generation (50.71 tok/s on Llama 2 7B) |
| 7th-gen NVENC and 5th-gen NVDEC with AV1 support | 16 GB VRAM limits Revan to the `vram16` tier (`mellum2.1-12b` `Q6_K` at 128K and `qwen3.5-9b` at 128K) |
| ECC video memory | Fewer CUDA cores (2,816) |
| Gen 4 Tensor cores with FP8 and BF16 support | Slower local generation than the Strix Halo hosts or `maul` |
| Single-slot, low-profile form factor | |
| Fits Revan's current local workload (`qwen3-embedding-0.6b`, `qwen3.5-9b`, and on-demand `mellum2.1-12b`) | |

### RTX 2080 Ti 22GB (potential swap)

| Pros | Cons |
|---|---|
| 2.15x faster token generation on the CUDA reference benchmark (109.17 versus 50.71 tok/s) | 250W TDP, requires 2x 8-pin PSU connectors, adds heat and noise |
| 22 GB VRAM unlocks the `vram22` tier (`mellum2.1-12b` `Q8_0` at 128K and `qwen3.5-9b` at 256K) | No AV1 encode or decode (6th-gen NVENC, 3rd-gen NVDEC) |
| 616 GB/s memory bandwidth | 5x peak power draw for an always-on server |
| 4,352 CUDA cores | Gen 2 Tensor cores (no FP8) and compute capability 7.5 |
| Faster local CUDA fallback when remote hosts are offline | Modified hardware with no warranty and an irreversible mod |

## Verdict

Keep the RTX 2000e Ada for now. Upgrade to the 2080 Ti 22GB only if Revan must serve interactive generation models locally rather than routing heavy requests to the Strix Halo hosts (`skrye` and `zannah`, `vram64`).

Revan's primary local GPU tasks are `qwen3-embedding-0.6b` embeddings, `qwen3.5-9b`, occasional `mellum2.1-12b` generation, and NVENC media transcoding. The RTX 2000e handles all four at 50W with AV1 hardware support. Swap to the 2080 Ti 22GB only if you want `vram22` (`mellum2.1-12b` `Q8_0` and 256K context on `qwen3.5-9b`) and faster local CUDA decode on Revan directly, and you accept higher power draw, extra heat, and the loss of AV1 transcoding.

## Hardware notes

- Despite being two architecture generations newer, the RTX 2000e Ada generates tokens at less than half the speed of the 2080 Ti on Llama 2 7B because Ada's newer Tensor cores cannot overcome a 2.75x memory bandwidth deficit.
- The Titan RTX (same Turing generation, full TU102 die, 384-bit bus) reaches 129 tok/s on `tg128`, only 18% faster than the 2080 Ti's 109.17 tok/s.
- The 22GB VRAM mod is purely a capacity upgrade. It keeps the stock 616 GB/s memory bandwidth while doubling addressable memory.

## Sources

- [llama.cpp CUDA Performance Scoreboard](https://github.com/ggml-org/llama.cpp/discussions/15013) - direct benchmark data for both GPUs
- [PNY RTX 2000e Ada Generation Product Page](https://www.pny.com/rtx-2000e-ada-generation)
- [TechPowerUp: RTX 2080 Ti 22GB Mod](https://www.techpowerup.com/282018/nvidia-geforce-rtx-2080-ti-modded-to-support-22-gb-of-gddr6-memory)
- [Linus Tech Tips: RTX 2080 Ti 22GB Build](https://linustechtips.com/topic/1497174-yesagainan-rtx-2080ti-22g-has-been-built/)
- [Tom's Hardware: RTX 2080 Ti 22GB Mod](https://www.tomshardware.com/news/nvidia-geforce-rtx-2080-ti-22gb-mod)
- [Jellyfin NVIDIA GPU Hardware Acceleration](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/)
