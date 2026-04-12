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
| ~19 GB | **qwen3.5:35b-a3b** | UD-Q4_K_XL | 3B (DeltaNet+MoE) | **~58 (measured)** |
| ~17 GB | **gemma4:26b** | default | 3.8B (MoE) | **48.28 (measured)** |
| ~5 GB | **gemma4:e4b** | default | 4.5B (dense eff.) | **56.41 (measured)** |
| ~19 GB | **gemma4:31b** | default | 30.7B (dense) | **10.42 (measured)** |
| ~19 GB | qwen3.5:27b | Q4_K_M | 27B (dense) | **11.91 (measured)** |
| ~51 GB | **qwen3-coder-next** | default | 3B (MoE) | **50.46 (measured)** |
| ~58 GB | gpt-oss:120b | Q4_K_M | ~12B (MoE) | 53-54 |
| ~40 GB | Llama 3.3 70B | Q4_K_M | 70B (dense) | ~5 |
| ~68 GB | Mistral Large 123B | Q4_K_M | 123B (dense) | ~3 |

**Ollama (Vulkan) - current deployment backend**

| RAM | Model | Active params | Decode tok/s | Notes |
|---|---|---|---|---|
| ~17 GB | qwen3-30b-a3b | 3.3B (MoE) | ~45 | ~48% slower than llama.cpp Vulkan on same model |
| ~24 GB | **qwen3.5:35b-a3b** | 3.3B (MoE) | **43.60 (measured)** | 3-run average; Vulkan vs ROCm historical 40.38 |
| ~17 GB | **gemma4:26b** | 3.8B (MoE) | **28.67 (measured)** | 3-run average |
| ~5 GB | **gemma4:e4b** | 4.5B (dense eff.) | **34.19 (measured)** | 3-run average |
| ~19 GB | **gemma4:31b** | 30.7B (dense) | **5.08 (measured)** | Bandwidth-ceilinged; 3-run average |
| ~17 GB | **qwen3.5:27b** | 27B (dense) | **10.99 (measured)** | Bandwidth-ceilinged; 3-run average |
| ~51 GB | **qwen3-coder-next** | 3B (MoE) | **34.35 (measured)** | 3-run average |
| ~11 GB | gpt-oss:20b | 3.6B (MoE) | ~46 | |
| ~58 GB | gpt-oss:120b | ~12B (MoE) | ~33 | |

Vulkan RADV outperforms ROCm by 17-25% for generation at standard context (ROCm catches up only at very long context prefill). Ollama adds a further ~32% overhead vs raw llama.cpp Vulkan (43.60 vs 57-58 tok/s on qwen3.5:35b-a3b). Dense large models (qwen3.5:27b, gemma4:31b) are memory-bandwidth-ceilinged at 10-11 tok/s regardless of backend; MoE models run at 48-58 tok/s. Switching to `llama-server` with Vulkan RADV is the single highest-impact optimisation for MoE models - see the README for the planned migration path.

**Practical budget**: reserve ~20-30GB for NixOS, desktop, and dev tools. This leaves ~100-110GB for Ollama. Multiple models can be pulled to disk; Ollama loads one at a time into RAM.

---

## 2. Does ZeroClaw Need Embedding Models?

Yes, strongly recommended.

ZeroClaw's memory pipeline has three stages: hot cache, FTS5 keyword search, and vector similarity search. Embeddings unlock stage 3 - semantic memory recall finds relevant memories even when the query shares no exact keywords with stored entries.

Without embeddings, ZeroClaw falls back to `NoopEmbedding`, which returns empty vectors and limits retrieval to keyword matching only. The `EmbeddingProvider` trait uses any OpenAI-compatible `/embeddings` endpoint, so Ollama embedding models work natively.

`llama-server` also exposes an OpenAI-compatible `/v1/embeddings` endpoint alongside a custom `/embedding` endpoint. One operational requirement for Qwen3-Embedding models: `--pooling last` must be passed explicitly at startup — the GGUF metadata does not carry this flag, so omitting it produces incorrect embeddings. One constraint: `--embedding` mode locks the server to embeddings only. A migration to `llama-server` for embeddings therefore requires two server processes — one for generation, one for embeddings.

For agents doing multi-session agentic work - PR reviews that reference earlier discussions, blog drafts that build on prior research - hybrid retrieval is meaningfully better than keyword-only.

---

## 3. llama.cpp Model Management

Two approaches exist for running multiple models under a single `llama-server` endpoint.

### Native router mode

Shipped December 2025 (PR #17470). Start `llama-server` without `-m` to enable auto-discovery from `--models-dir`. Models load on demand, are evicted by LRU when the count reaches `--models-max`, and are selected per-request via the `model` field. Manual control is available via `/models/load` and `/models/unload` APIs. Per-model settings go in `--models-preset config.ini`. Marked experimental.

### llama-swap

[llama-swap](https://github.com/mostlygeek/llama-swap) is a Go binary (~3K stars) that sits in front of one or more `llama-server` processes and routes requests by model name. More mature than the native router for mixed generation/embedding workloads. Key features: always-on groups (an embedding model stays resident while generation models swap in and out), per-model TTLs, mixed backends, and `/v1/embeddings` routing. The more reliable choice for production use until the native router matures.

### Comparison to Ollama

Ollama's integrated load/unload is more polished than either option above. Both llama-server router mode and llama-swap are functional but require more manual configuration.

---

## 4. The Models: Inference

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

## 5. The Models: Embedding

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

**Context window:** The official Ollama Modelfile for `qwen3-embedding:4b-q8_0` sets `num_ctx` to the model's full 40,960-token native context. No additional configuration is required.

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

## 6. Split-Host Strategy

Should Skrye and Zannah run different model families - Qwen on one, Gemma on the other?

No. Run the same model stack on both hosts.

**Same workloads, same quality bar.** Both hosts run identical agent tasks. Different model families produce different output styles and tool-calling behaviours, creating inconsistent quality that is harder to evaluate and tune.

**Operational simplicity.** One Nix configuration, one set of system prompts tuned for one model's behaviour, one set of known failure modes. Maintaining two prompt sets doubles the tuning surface.

**No cross-host diversity benefit.** Since instances share no memory, there is no advantage from running different models; you cannot route "this task suits Gemma better" because each host handles whatever arrives independently.

**Redundancy value.** Identical stacks mean either host can substitute for the other if one goes down.

When splitting would make sense (not applicable here): A/B testing model quality with identical prompts, routing task types to specialised models, or running different size tiers for explicit latency targets.

---

## 7. Recommendations

### Embedding: qwen3-embedding:4b-q8_0

~5 GB at Q8_0, 40K context, code retrieval capable. Load permanently alongside inference models. The 4B sits at the quality optimum: +4.96 MTEB retrieval and +4.65 MTEB Code over the 0.6B, with the 8B adding only 0.62 further points at half the throughput. Q8_0 preserves embedding fidelity that Q4_K_M would compromise; the ~5 GB memory cost is trivial on 128 GB.

Use `qwen3-embedding:4b-q8_0` directly. The model's native 40K context is fully available — no additional configuration required.

Skip nomic-embed-text-v2-moe (512-token context too short for code chunks) and embeddinggemma (2K context, no advantage over qwen3-embedding).

### Model Stack Per Host

| Slot | Model | Disk | Active params | Context | tok/s | Primary use |
|---|---|---|---|---|---|---|
| Coding | qwen3-coder-next | 51 GB | 3B (MoE) | 256K | ~50 | Agentic coding, PR review, multi-step |
| General | qwen3.5:35b-a3b | 24 GB | 3.3B (MoE) | 256K | ~58 | Structured output, precision tasks, general reasoning |
| Small / media | gemma4:e4b | ~5 GB | 4.5B (eff) | 128K | ~56 | Summarisation, image/video triage, fast tasks |
| Embedding | qwen3-embedding:4b-q8_0 | ~5 GB | 4B | 40K | — | Memory retrieval |
| **Total** | | **~85 GB** | | | | |

Total disk ~85GB leaves ~25GB headroom in the 110GB practical budget. Ollama loads one inference model at a time; all fit comfortably in 128GB with space for context windows and desktop workload.

### ZeroClaw Config Pattern

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

### Rationale Summary

- **qwen3-coder-next as coding primary**: 80B total / 3B active MoE - throughput governed by active parameters, not total. Measured 50 tok/s vs qwen3.5:27b's 11 tok/s, a 4.5x speed advantage. SWE-Bench Verified 70.6% vs qwen3.5:27b's 72.4% - a marginal quality trade. LiveCodeBench 58.9% vs 80.7% - weaker on single-shot algorithmic tasks; qwen3.5:35b-a3b covers that precision gap. Designed for agentic retry loops: Pass@5 rank 1 on SWE-rebench. 256K context for repo-scale work.
- **qwen3.5:35b-a3b as general**: 3.3B active MoE, 256K context. Measured 58 tok/s. Community hard-task testing scores 10/10 on agentic patterns; use for structured output, precision tasks, and the algorithmic reasoning gap qwen3-coder-next leaves open. Self-correction in an agent loop compensates for its 0/6 structured output score on hard-task benchmarks.
- **gemma4:e4b as small/media model**: The only local model in the stack with audio and video capability - neither of the larger Gemma 4 models has an audio encoder. Image and video (frame sequences up to 60 seconds) work today. Audio transcription and understanding are model-supported but pending llama.cpp and Ollama implementation; use Q6_K when audio lands. At ~5 GB and ~56 tok/s (llama-bench measured) it handles summarisation, fast triage, and lightweight tasks without loading a larger model.
- **Frontier fallback**: Local models handle the 80-90% routine case; Claude handles deep research and complex multi-step reasoning that exceeds the local tier.

**Community validation:** Independent benchmarking on Strix Halo hardware and ZeroClaw/agent-stack community reports confirm the MoE-for-loops pattern. No ZeroClaw-specific model list exists - the agent software is model-agnostic. Gemma4:e4b is treated by practitioners as a multimodal model only, consistent with its role in this stack.

### NixOS Model Pre-seeding (llama-server)

This is the primary operational gap in a llama-server deployment versus Ollama's `services.ollama.loadModels`.

llama.cpp has no dedicated download tool. The `-hf` flag downloads models at runtime to `~/.cache/llama.cpp`, which is unsuitable for a server deployment. The right pre-seeding tool is `huggingface-cli` from `pkgs.python3Packages.huggingface-hub`:

```bash
huggingface-cli download <repo> <file> --local-dir /var/lib/llama-models
```

The NixOS pattern is a systemd oneshot service that runs `huggingface-cli download` before `llama-server` starts, with models stored in `/var/lib/llama-models/`. This requires a custom module — nixpkgs PR #488117 adds `hfRepo`/`hfFile` options directly to `services.llama-cpp` with download at service start, but it has not yet merged. Until it does, the download oneshot must be written by hand.

### Models Evaluated and Set Aside

| Model | Reason |
|---|---|
| qwen3.5:122b | 81GB leaves ~29GB for NixOS + desktop + context; ~3.4 tok/s impractical for interactive work |
| qwen3.5:27b | Dense 27B; measured 11 tok/s - bandwidth-ceilinged regardless of backend. qwen3-coder-next provides 4.5x throughput at comparable SWE-Bench quality (70.6% vs 72.4%). |
| gemma4:31b | Dense 30.7B; measured 5-10 tok/s - same bandwidth ceiling as qwen3.5:27b. gemma4:26b MoE delivers 48 tok/s at near-identical quality. |
| gemma4:26b | MoE, 3.8B active, 48 tok/s measured. Considered as alternative general model; qwen3.5:35b-a3b preferred for stronger structured output and Qwen family consistency. |
| qwen3-coder:30b | Superseded; old Qwen3 architecture with 3.3B active params scores 50.3% SWE-Bench vs qwen3-coder-next's 70.6% |
| qwen3-embedding:0.6b | Quality plateau at 4B; 0.6B suitable only for resource-constrained hardware |
| qwen3-embedding:8b | 4B-to-8B delta is 0.62 points on code retrieval; 4B at Q8_0 is the quality/throughput optimum |
| nomic-embed-text-v2-moe | 512-token context too short for code chunks |
| embeddinggemma | No advantage over qwen3-embedding at 2K context |

---

## 8. Key References

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
| llama-swap | https://github.com/mostlygeek/llama-swap |
| nixpkgs PR #488117 - llama-cpp hfRepo/hfFile | https://github.com/NixOS/nixpkgs/pull/488117 |
