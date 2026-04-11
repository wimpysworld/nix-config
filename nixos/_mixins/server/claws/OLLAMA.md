# Ollama Model Selection for ZeroClaw

Decision document for local inference model selection on Skrye and Zannah. Covers hardware constraints, embedding requirements, candidate model evaluation, and the recommended stack.

---

## 1. Hardware Context

Each host: AMD Ryzen AI Max+ 395 (Strix Halo), 128GB unified LPDDR5X, ~270 GB/s memory bandwidth.

Measured decode speeds on Strix Halo (Ryzen AI Max+ 395, 128GB, ~212 GB/s practical bandwidth). MoE model throughput is governed by active parameters, not total parameters - a 30B MoE with 3B active runs faster than a 7B dense model.

**llama.cpp (Vulkan RADV) - recommended for generation-heavy workloads**

| RAM | Model example | Quant | Active params | Decode tok/s |
|---|---|---|---|---|
| ~2 GB | Llama 3.2 3B | Q4_K_XL | 3.2B (dense) | ~93 |
| ~4 GB | Llama 2 7B | Q4_K_M | 6.7B (dense) | ~47 |
| ~6 GB | Qwen2.5-Coder 7B | Q6_K | 7.6B (dense) | ~37 |
| ~8 GB | Qwen2.5 14B | Q4_K_M | 14.8B (dense) | ~25 |
| ~11 GB | gpt-oss:20b | MXFP4 | 3.6B (MoE) | ~77 |
| ~17 GB | qwen3-30b-a3b | Q4_K_M | 3.3B (MoE) | 83-86 |
| ~18 GB | Nemotron-3-Nano-30B | IQ4_NL | 3.5B (MoE) | ~76 |
| ~19 GB | **qwen3.5:35b-a3b** | UD-Q4_K_XL | 3B (DeltaNet+MoE) | 42-49 |
| ~19 GB | qwen3.5:27b | Q4_K_M | 27B (dense) | ~14 |
| ~43 GB | Qwen3-Coder-Next 80B | Q4_K_M | 3B (MoE) | ~43 |
| ~58 GB | gpt-oss:120b | Q4_K_M | ~12B (MoE) | 53-54 |
| ~40 GB | Llama 3.3 70B | Q4_K_M | 70B (dense) | ~5 |
| ~68 GB | Mistral Large 123B | Q4_K_M | 123B (dense) | ~3 |

**Ollama (ROCm) - current deployment backend**

| RAM | Model example | Decode tok/s | Notes |
|---|---|---|---|
| ~17 GB | qwen3-30b-a3b | ~45 | ~48% slower than llama.cpp Vulkan on same model |
| ~20 GB | **qwen3.5:35b-a3b** | ~40 | Q8_0 measured |
| ~18 GB | qwen3.5:27b (dense) | ~9 | Dense models hit hardest by Ollama overhead |
| ~11 GB | gpt-oss:20b | ~46 | |
| ~58 GB | gpt-oss:120b | ~33 | |

Vulkan RADV outperforms ROCm by 17-25% for generation at standard context (ROCm catches up only at very long context prefill). Ollama adds a further ~40-50% overhead vs raw llama.cpp. Switching to `llama-server` with Vulkan RADV is the single highest-impact optimisation - see the README for the planned migration path.

**Note:** GPU clock must be set to high performance (`power_dpm_force_performance_level=high`) or throughput halves. Without this, the GPU idles at 600 MHz.

**Practical budget**: reserve ~20-30GB for NixOS, desktop, and dev tools. This leaves ~100-110GB for Ollama. Multiple models can be pulled to disk; Ollama loads one at a time into RAM.

---

## 2. Does ZeroClaw Need Embedding Models?

Yes, strongly recommended.

ZeroClaw's memory pipeline has three stages: hot cache, FTS5 keyword search, and vector similarity search. Embeddings unlock stage 3 - semantic memory recall finds relevant memories even when the query shares no exact keywords with stored entries.

Without embeddings, ZeroClaw falls back to `NoopEmbedding`, which returns empty vectors and limits retrieval to keyword matching only. The `EmbeddingProvider` trait uses any OpenAI-compatible `/embeddings` endpoint, so Ollama embedding models work natively.

For agents doing multi-session agentic work - PR reviews that reference earlier discussions, blog drafts that build on prior research - hybrid retrieval is meaningfully better than keyword-only.

---

## 3. The Models: Inference

### Gemma 4 (Google DeepMind)

Gemma 4 is Google DeepMind's fourth-generation open model family. The line spans from edge-tier multimodal models to a full 31B dense variant, all with native function calling and configurable thinking mode.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| E2B | 7.2 GB | Dense (2.3B effective) | 128K | Edge-tier, multimodal |
| E4B | 9.6 GB | Dense (4.5B effective) | 128K | Lightweight workhorse, multimodal |
| 26B MoE | 18 GB | MoE, 128 experts, 3.8B active | 256K | Best efficiency/quality ratio |
| 31B | 20 GB | Dense (30.7B) | 256K | Maximum quality, native function calling |

The 26B MoE scores AIME 2026 88.3% versus 89.2% for the 31B dense - a 2% quality trade for meaningfully faster inference. Native function calling, configurable thinking mode, and system prompt support are present across the family.

The standout is the 26B MoE: near-31B quality at better throughput, with 256K context for large PRs and multi-file reviews.

#### Gemma 4 E2B and E4B: audio and vision variants

The E2B and E4B are the only Gemma 4 variants with audio capability. The 26B and 31B models have no audio encoder.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| E2B | ~3 GB | Dense (2.3B effective) + audio encoder | 128K | Smallest; audio/vision capable |
| E4B (recommended) | ~5 GB | Dense (4.5B effective) + audio encoder | 128K | Better quality; audio/vision capable |

The architecture includes a ~150M vision encoder for image and video input and a ~300M USM-style conformer encoder for audio.

**What works in Ollama today:** image and video input (video via frame extraction, up to 60 seconds at 1 fps through the image path).

**What does not yet work in Ollama:** audio input. The llama.cpp conformer encoder PR (#21421) has merge conflicts as of April 2026 and has not merged. Ollama has no audio API endpoint - the model tag on the Ollama library page reflects model capability, not current Ollama support.

When audio support lands, use Q6_K quantisation minimum - Q4_K_M is unreliable for audio transcription on longer clips. Audio constraints when available: 30-second max per clip, no speaker diarisation, no word-level timestamps; longer recordings require VAD chunking before submission.

Speed on Strix Halo: ~48-50 tok/s. At this size the model is compute-bound, not memory-bandwidth-bound.

### Qwen 3.5 (Alibaba)

Qwen 3.5 is Alibaba's frontier general-purpose model series, explicitly designed for the "agentic AI era." The architecture combines Gated Delta Networks with sparse MoE, yielding strong knowledge recall and tool use across a wide size range.

| Variant | Disk | Architecture | Context | Notes |
|---|---|---|---|---|
| 9B | 6.6 GB | Hybrid MoE | 256K | Light tasks |
| 27B | 17 GB | Dense, DeltaNet hybrid | 256K | Primary workhorse; all 27B params active per token |
| 35B | 24 GB | Hybrid MoE | 256K | MoE general-purpose variant |
| 122B | 81 GB | Hybrid MoE | 256K | Technically fits but impractical on a workstation |

The flagship 397B-A17B scores BFCL-V4 72.9, MCP-Mark 46.1, and TAU2-Bench 86.7. Smaller variants inherit the agentic architecture. Strong knowledge recall (80.6 average versus Gemma 4 31B's 61.3), 201 languages, vision, tool use, and thinking mode.

The 27B uses a Gated DeltaNet hybrid architecture - linear attention alternating with standard attention, new to the Qwen3.5 generation. All 27B parameters are active per forward pass. SWE-Bench Verified 72.4%, LiveCodeBench v6 80.7%, IFEval 95.0%, TAU2-Bench 79.0%. Native multimodal (text, image, video). Despite being smaller on disk than the 35B MoE, it scores higher on every coding benchmark.

Community hard-task testing on Strix Halo (frank-besson/llama-strix-halo benchmark, 30 tasks) found qwen3.5:35b-a3b scores 10/10 on agentic patterns but 0/6 on structured output constraints and instruction following - high variance on tasks requiring strict output formatting. This reinforces the role split: use qwen3.5:35b-a3b for agent loops where the scaffold can self-correct, and qwen3.5:27b for tasks requiring one-shot precision and structured output.

---

## 4. The Models: Embedding

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

**Quantisation:** embedding quality degrades more with aggressive quantisation than generation quality does. The default Ollama tag uses Q4_K_M. On this hardware (128GB), use Q8_0: pull `qwen3-embedding:4b-q8_0`. Memory cost is ~5 GB at Q8 versus ~2.5 GB at Q4 - trivial on 128 GB.

**Context window:** Ollama defaults to 4096 tokens regardless of the model's native 40K context. ZeroClaw's embedding provider cannot pass `num_ctx` to the embeddings endpoint - it sends only `model` and `input`. Set `num_ctx` via a Modelfile alias instead (see §6). 8192 covers most ZeroClaw memory entries and PR diffs; 16384 covers edge cases (large diffs, research documents).

**Reranker note:** a Qwen3-Reranker-4B on top of qwen3-embedding:0.6B scores 81.20 on MTEB Code, higher than qwen3-embedding:8B alone (80.68). Worth considering as a future enhancement if retrieval quality becomes a bottleneck after deployment.

### nomic-embed-text-v2-moe (Nomic AI)

| Property | Value |
|---|---|
| Disk | 958 MB |
| Context | 512 tokens |
| Dimensions | 768 (Matryoshka, flexible down to 256) |
| Params | 475M (305M active, MoE) |

BEIR 52.86, MIRACL 65.80. Multilingual (~100 languages). The 512-token limit is too short for code chunks.

### embeddinggemma (Google)

| Property | Value |
|---|---|
| Disk | 622 MB |
| Context | 2K tokens |
| Params | 300M |

Built from Gemma 3/T5Gemma, designed for on-device deployment. 2K context is better than nomic but far short of qwen3-embedding's 32K.

---

## 5. Split-Host Strategy

Should Skrye and Zannah run different model families - Qwen on one, Gemma on the other?

No. Run the same model stack on both hosts.

**Same workloads, same quality bar.** Both hosts run identical agent tasks. Different model families produce different output styles and tool-calling behaviours, creating inconsistent quality that is harder to evaluate and tune.

**Operational simplicity.** One Nix configuration, one set of system prompts tuned for one model's behaviour, one set of known failure modes. Maintaining two prompt sets doubles the tuning surface.

**No cross-host diversity benefit.** Since instances share no memory, there is no advantage from running different models; you cannot route "this task suits Gemma better" because each host handles whatever arrives independently.

**Redundancy value.** Identical stacks mean either host can substitute for the other if one goes down.

When splitting would make sense (not applicable here): A/B testing model quality with identical prompts, routing task types to specialised models, or running different size tiers for explicit latency targets.

---

## 6. Recommendations

### Embedding: qwen3-embedding:4b-q8_0

~5 GB at Q8_0, 40K context, code retrieval capable. Load permanently alongside inference models. The 4B sits at the quality optimum: +4.96 MTEB retrieval and +4.65 MTEB Code over the 0.6B, with the 8B adding only 0.62 further points at half the throughput. Q8_0 preserves embedding fidelity that Q4_K_M would compromise; the ~5 GB memory cost is trivial on 128 GB.

Use the `qwen3-embedding:4b-q8_0-8k` alias (not the base model tag) in ZeroClaw config. ZeroClaw cannot pass `num_ctx` to the embeddings endpoint; the NixOS Ollama mixin creates this alias via a Modelfile with `num_ctx 8192` baked in. Ollama's 4096 default otherwise discards most of the model's native 40K context window.

Skip nomic-embed-text-v2-moe (512-token context too short for code chunks) and embeddinggemma (2K context, no advantage over qwen3-embedding).

### Model Stack Per Host

| Slot | Model | Disk | Active params | Context | Primary use |
|---|---|---|---|---|---|
| Primary workhorse | qwen3.5:27b | 17 GB | 27B | 256K | PR review, code fixes, agentic coding, research |
| General | qwen3.5:35b-a3b | 24 GB | 3.3B (MoE) | 256K | General reasoning, research, tasks not requiring one-shot precision |
| Small / media | gemma4:e4b | ~5 GB | 4.5B (effective) | 128K | Summarisation, image/video triage, fast text tasks; audio pending Ollama support |
| Embedding | qwen3-embedding:4b-q8_0 | ~5 GB | 4B | 40K | Memory retrieval |
| **Total on disk** | | **~51 GB** | | | |

Total disk ~51GB leaves ~59GB headroom in the 110GB practical budget. Ollama loads one inference model at a time; all fit comfortably in 128GB with space for context windows and desktop workload.

### ZeroClaw Config Pattern

```toml
[[model_list]]
model_name = "primary"
model = "ollama/qwen3.5:27b"
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
# Use the 8k alias, not the base model. ZeroClaw cannot pass num_ctx to the
# embeddings endpoint; the alias has num_ctx 8192 baked in via Modelfile.
embedding_model = "ollama/qwen3-embedding:4b-q8_0-8k"
embedding_base = "http://<host-container-ip>:11434/v1"
```

### Rationale Summary

- **qwen3.5:27b as primary**: Dense 27B - all parameters active per forward pass on the new DeltaNet hybrid architecture. SWE-Bench Verified 72.4%, LiveCodeBench 80.7%, IFEval 95.0%. Beats both qwen3-coder:30b (50.3% SWE-Bench) and qwen3.5:35b-a3b MoE (69.2%) despite being smaller on disk - active parameter count matters more than total parameter count. 256K context for repo-scale work.
- **qwen3.5:35b-a3b as general**: 3.3B active MoE, 256K context, 256K context. Faster than the dense 27B at equivalent or better general reasoning; use for research, broad knowledge tasks, and anything not requiring one-shot structured output precision. Community hard-task testing scores 10/10 on agentic patterns; self-correction in an agent loop compensates for its 0/6 structured output score.
- **gemma4:e4b as small/media model**: The only local model in the stack with audio and video capability - neither of the larger Gemma 4 models has an audio encoder. Image and video (frame sequences up to 60 seconds) work today. Audio transcription and understanding are model-supported but pending llama.cpp and Ollama implementation; use Q6_K when audio lands. At ~5 GB and ~48-50 tok/s it handles summarisation, fast triage, and lightweight tasks without loading a larger model.
- **Frontier fallback**: Local models handle the 80-90% routine case; Claude handles deep research and complex multi-step reasoning that exceeds the local tier.

**Community validation:** Independent benchmarking on Strix Halo hardware and ZeroClaw/agent-stack community reports confirm the MoE-for-loops, dense-for-precision role split. No ZeroClaw-specific model list exists - the agent software is model-agnostic. The 35B-A3B / 27B combination appears consistently in high-memory agentic setups. Gemma4:e4b is treated by practitioners as a multimodal model only, consistent with its role in this stack.

### Models Evaluated and Set Aside

| Model | Reason |
|---|---|
| qwen3.5:122b | 81GB leaves ~29GB for NixOS + desktop + context; ~3.4 tok/s impractical for interactive work |
| gemma4:26b | Replaced by qwen3.5:35b-a3b for general tasks; gemma4:e4b covers media and summarisation at lower cost |
| qwen3-coder:30b | Superseded; old Qwen3 architecture with 3.3B active params scores 50.3% SWE-Bench vs qwen3.5:27b's 72.4% |
| qwen3-coder-next:80b | **Qwen3-Coder-Next** (80B MoE, 3B active, ~43GB IQ4): SWE-Bench Verified 70.6%, 45 tok/s on Strix Halo, 23/30 on community hard-task benchmark (joint highest). Fits within the 96GB budget alongside embedding and gemma4:e4b (~53GB total). Community hard-task data supports treating this as an optional high-quality coding specialist rather than a future consideration. Add if one-shot coding precision on hard tasks becomes a priority; the 35B-A3B and 27B cover the baseline well without it. |
| qwen3-embedding:0.6b | Quality plateau at 4B; 0.6B suitable only for resource-constrained hardware |
| qwen3-embedding:8b | 4B-to-8B delta is 0.62 points on code retrieval; 4B at Q8_0 is the quality/throughput optimum |
| nomic-embed-text-v2-moe | 512-token context too short for code chunks |
| embeddinggemma | No advantage over qwen3-embedding at 2K context |

---

## 7. Key References

| Resource | URL |
|---|---|
| Ollama - Gemma 4 | https://ollama.com/library/gemma4 |
| Ollama - Qwen 3.5 | https://ollama.com/library/qwen3.5 |
| Ollama - qwen3-embedding | https://ollama.com/library/qwen3-embedding |
| Ollama - nomic-embed-text-v2-moe | https://ollama.com/library/nomic-embed-text-v2-moe |
| Ollama - embeddinggemma | https://ollama.com/library/embeddinggemma |
| BenchLM - Gemma 4 31B vs Qwen3.5-27B | https://benchlm.ai/compare/gemma-4-31b-vs-qwen3-5-27b |
| Alibaba Cloud - Qwen3.5 | https://www.alibabacloud.com/blog/602894 |
| Hacker News - Strix Halo bandwidth | https://news.ycombinator.com/item?id=45877149 |
