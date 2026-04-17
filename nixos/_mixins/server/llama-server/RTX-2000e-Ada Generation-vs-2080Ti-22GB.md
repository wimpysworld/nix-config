# RTX 2000e Ada Generation vs 2080 Ti 22GB: Revan GPU Comparison

## The Numbers Tell a Clear Story

The llama.cpp CUDA scoreboard provides direct, comparable benchmarks on a standard workload (Llama 2 7B Q4_0). Both cards are in the dataset.

| Metric | RTX 2000e Ada | RTX 2080 Ti (stock 11GB) | 2080 Ti Advantage |
|--------|--------------|------------------------|-------------------|
| **pp512 (no FA)** | 1,956 tok/s | 2,891 tok/s | **+48%** |
| **pp512 (FA)** | 2,250 tok/s | 3,108 tok/s | **+38%** |
| **tg128 (no FA)** | 50.62 tok/s | 107.51 tok/s | **+112%** |
| **tg128 (FA)** | 50.71 tok/s | 109.17 tok/s | **+115%** |

📌 **KEY**: The 2080 Ti delivers **2.15x faster token generation** - the metric that matters most for interactive inference. Prompt processing is 1.4x faster. The delta is driven entirely by memory bandwidth: 616 GB/s (352-bit) vs 224 GB/s (128-bit). The 22GB mod does not change bandwidth - it replaces each 1GB GDDR6 chip with a 2GB chip on the same bus.

## Full Spec Comparison

| Spec | RTX 2000e Ada | RTX 2080 Ti (22GB mod) | Notes |
|------|--------------|----------------------|-------|
| **Architecture** | Ada Lovelace (AD107) | Turing (TU102) | 2 generations apart |
| **Compute capability** | 8.9 | 7.5 | Ada has FP8, BF16 support |
| **CUDA cores** | 2,816 | 4,352 | 2080 Ti has 1.55x more |
| **Tensor cores** | 88 (Gen 4) | 544 (Gen 2) | Gen 4 has FP8; Gen 2 is FP16 only |
| **VRAM** | 16 GB GDDR6 ECC | 22 GB GDDR6 (modded) | 2080 Ti has 37% more VRAM |
| **Memory bus** | 128-bit | 352-bit | 2.75x wider |
| **Memory bandwidth** | 224 GB/s | 616 GB/s | 2.75x higher |
| **TDP** | 50W (bus-powered) | 250W (2x 8-pin PCIe) | **5x power draw** |
| **Form factor** | Single-slot, half-height | 2-slot, full-height | Both fit Revan's slot |
| **PCIe power** | None (bus-powered) | 2x 8-pin required | PSU connectors needed |
| **NVENC** | 7th gen (AV1 encode+decode) | 6th gen (no AV1 encode) | Ada has AV1 |
| **NVDEC** | 5th gen (AV1 decode) | 3rd gen (no AV1 decode) | Ada has AV1 decode |
| **FP32 TFLOPS** | 8.9 | ~13.4 | 2080 Ti has 1.5x raw compute |
| **Tensor TOPS (INT8)** | 71 | N/A (Gen 2 = FP16 only) | Ada wins for quantised inference |

## The 22GB VRAM Mod

The mod replaces the eleven 1GB (8Gbit) GDDR6 chips on the PCB with 2GB (16Gbit) chips of the same speed grade. This doubles capacity from 11 GB to 22 GB. What stays the same: memory clock, bus width, bandwidth, compute performance. What changes: only the addressable VRAM. Modern mods using proper 16Gbit Samsung/Micron K4ZAF325BM or equivalent chips are reported stable. The mod is irreversible.

## Impact on Revan's Workloads

### Embedding and re-ranking

Both GPUs handle this trivially. qwen3-embedding:4b-q8_0 (~5 GB) and a future re-ranker (~5 GB) run comfortably on either card. The 2080 Ti's higher bandwidth would process embedding batches faster, but embedding is not the bottleneck in the RAG pipeline - retrieval latency is dominated by query time, not embedding throughput.

### Small local model

Here the gap widens. On the RTX 2000e, qwen3:1.7b is the practical ceiling for always-loaded models alongside embedding. On the 2080 Ti 22GB, you could run a 9B model (qwen3.5:9b at ~6.6 GB) or even a 13B model at Q4 (~8 GB) and still have room for embedding + re-ranking + Jellyfin. A 9B model running at ~100+ tok/s on the 2080 Ti (extrapolating from the benchmark ratios) would be a meaningfully more capable local model than qwen3:1.7b at ~50 tok/s on the 2000e.

### Jellyfin transcoding

⚠️ **CAVEAT**: The 2080 Ti has a 6th-gen NVENC - no AV1 encode or decode. H.264 and H.265 encoding/decoding still work. If your media library is heavy on AV1 content or you want AV1 output, the RTX 2000e's 7th-gen NVENC is materially better. If your library is predominantly H.264/H.265, the encoding quality difference between 6th-gen and 7th-gen NVENC is marginal for those codecs.

### Power and thermals

This is the decisive operational trade-off for an always-on server. The RTX 2000e draws 50W at peak, bus-powered, passively acceptable in a quiet home server. The 2080 Ti draws 250W at peak under sustained inference load, requires two 8-pin PCIe power connectors, and produces proportionally more heat and fan noise. At idle the 2080 Ti drops to ~20-30W, but during active inference (which could be frequent with ZeroClaw's embedding pipeline and local model), sustained draw is 150-200W.

Over 24 hours of mixed use (assume 4 hours active inference at 200W, 20 hours idle at 25W):
- **RTX 2000e**: ~50W × 4h + ~10W × 20h = 400 Wh/day → ~146 kWh/year
- **RTX 2080 Ti**: ~200W × 4h + ~25W × 20h = 1300 Wh/day → ~475 kWh/year

At UK electricity rates (~28p/kWh), that's roughly **£42/year vs £133/year** - a £91 annual difference.

## Pros and Cons Summary

### RTX 2000e Ada (current)

| Pros | Cons |
|------|------|
| 50W bus-powered - no PSU cables, silent-friendly | 128-bit bus limits token generation to ~51 tok/s |
| 7th-gen NVENC with AV1 encode+decode | 16 GB VRAM limits local model size |
| ECC memory - zero risk of bit-flip errors in embeddings | Fewer CUDA cores (2,816) |
| Gen 4 Tensor cores with FP8 support | Cannot run models larger than ~9B alongside embedding |
| Single-slot, low-profile form factor | |
| Adequate for current workload (embedding + 1.7B) | |

### RTX 2080 Ti 22GB (potential swap)

| Pros | Cons |
|------|------|
| 2.15x faster token generation (109 vs 51 tok/s) | 250W TDP - requires PSU connectors, produces heat/noise |
| 22 GB VRAM - room for a 9-13B local model | No AV1 encode/decode (6th-gen NVENC) |
| 616 GB/s memory bandwidth | 5x power draw for an always-on server |
| 4,352 CUDA cores | Gen 2 Tensor cores (no FP8) |
| Could run gemma4:e4b or qwen3.5:9b locally | Compute capability 7.5 - older CUDA features |
| Meaningfully expands what Revan can do locally | Modified hardware - no warranty, irreversible mod |

## Verdict

→ **Keep the RTX 2000e for now. The 2080 Ti is a worthwhile future upgrade, but only if you find yourself wanting a larger local model on Revan.**

The current architecture routes heavy inference to the Strix Halos. Revan's GPU role is embedding, a tiny local model, and Jellyfin - all of which the RTX 2000e handles within its comfort zone. The 2080 Ti's 2x speed advantage matters when you're running interactive models, but the qwen3:1.7b "simple tasks" model is already fast enough at 50 tok/s for classification and formatting.

The 2080 Ti becomes compelling if you want to:
- Run a 9B+ model on Revan as a capable local fallback (not just "simple tasks")
- Reduce dependence on the Strix Halos for medium-complexity work
- Accept the power and noise trade-off

The trigger to swap: if you find qwen3:1.7b insufficient for Revan's local workload and want a model like qwen3.5:9b or gemma4:e4b always available on the hub without routing to a Strix Halo. The 2080 Ti 22GB would handle that comfortably with room to spare.

---

## Interesting Findings

- The RTX 2000e Ada, despite being two architecture generations newer, is **less than half** the token generation speed of the 2080 Ti. Architecture improvements in Ada (FP8, better Tensor cores, efficiency) cannot compensate for a 2.75x memory bandwidth deficit. For LLM inference, bandwidth is king.
- The Titan RTX (same generation as 2080 Ti, full TU102 die, 384-bit bus) benchmarks at 129 tok/s tg128 - only 18% faster than the 2080 Ti's 109 tok/s, despite the wider bus. The 2080 Ti extracts most of the Turing generation's potential.
- The 22GB mod doesn't change performance at all - it's purely a capacity upgrade. You get the same 616 GB/s bandwidth with double the addressable memory.

## Sources

- [llama.cpp CUDA Performance Scoreboard](https://github.com/ggml-org/llama.cpp/discussions/15013) - direct benchmark data for both GPUs
- [PNY RTX 2000e Ada Generation Product Page](https://www.pny.com/rtx-2000e-ada-generation)
- [TechPowerUp: RTX 2080 Ti 22GB Mod](https://www.techpowerup.com/282018/nvidia-geforce-rtx-2080-ti-modded-to-support-22-gb-of-gddr6-memory)
- [Linus Tech Tips: RTX 2080 Ti 22GB Build](https://linustechtips.com/topic/1497174-yesagainan-rtx-2080ti-22g-has-been-built/)
- [Tom's Hardware: RTX 2080 Ti 22GB Mod](https://www.tomshardware.com/news/nvidia-geforce-rtx-2080-ti-22gb-mod)
- [Jellyfin NVIDIA GPU Hardware Acceleration](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/)
