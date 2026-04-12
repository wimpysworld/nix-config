# Strix Halo Performance Configuration

> AMD Ryzen AI Max+ 395 (gfx1151, RDNA3.5) · 128 GB LPDDR5X · Framework Desktop · Ollama 0.20.2 on NixOS 25.11

---

## 1. Ollama Backend: Vulkan

Use `pkgs.ollama-vulkan`. The existing Ollama mixin selects this automatically when `host.gpu.compute.acceleration = "vulkan"`. Both Skrye and Zannah have `acceleration = "vulkan"` in the registry.

Ollama Vulkan works correctly on Strix Halo gfx1151 with Ollama 0.20.2. The following issues were previously reported but are not observed in practice:

- iGPU VRAM detection: no detection issue observed; full unified memory is visible on the Vulkan path.
- MoE model output: no garbled output observed with `gemma4:e4b` or `qwen3.5:35b-a3b`. The earlier recommendation to avoid Vulkan was based on unverified reports and is retracted.

Vulkan delivers 43.60 tok/s on qwen3.5:35b-a3b versus ROCm's 40.38 tok/s - an 8% throughput gain - at lower power draw (~78 W vs ~92 W).

**Do not set `rocmOverrideGfx`.** Ollama 0.18+ bundles ROCm 7.2 with native gfx1151 detection. `HSA_OVERRIDE_GFX_VERSION=11.5.1` is no longer required and can cause issues. The NixOS `services.ollama.rocmOverrideGfx` option must not be set for this hardware.

---

## 2. Performance Environment Variables

Add these to `services.ollama.environmentVariables` in the Ollama mixin's `isInference` block:

| Variable | Value | Rationale |
|---|---|---|
| `OLLAMA_FLASH_ATTENTION` | `"1"` | Reduces KV cache size; faster prompt processing. Required for KV cache quantisation. |
| `OLLAMA_KV_CACHE_TYPE` | `"q8_0"` | Halves KV cache vs f16 with minimal quality impact. Enables larger context or larger models. |
| `OLLAMA_KEEP_ALIVE` | `"-1"` | Models stay loaded indefinitely. Avoids reload latency for agent workloads. |
| `OLLAMA_NUM_PARALLEL` | `"1"` | Single-user, sequential requests. Higher values multiply KV cache memory. |
| `OLLAMA_MAX_LOADED_MODELS` | `"1"` | One model at a time. Prevents memory contention. |

**Additional AMD/unified memory variables** — community-reported; verify on your hardware:

| Variable | Value | Rationale |
|---|---|---|
| `GGML_CUDA_ENABLE_UNIFIED_MEMORY` | `"1"` | [community-reported] [uncertain - verify on your hardware] May help ROCm use all unified RAM on the APU. |
| `HSA_XNACK` | `"1"` | [community-reported] [uncertain - verify on your hardware] Enables XNACK page fault recovery for unified memory on Strix Halo. |

**Proposed addition to `nixos/_mixins/server/ollama/default.nix`:**

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-vulkan;
  host = if host.is.server then "0.0.0.0" else "127.0.0.1";
  loadModels = allModels;
  environmentVariables = {
    OLLAMA_FLASH_ATTENTION    = "1";
    OLLAMA_KV_CACHE_TYPE      = "q8_0";
    OLLAMA_KEEP_ALIVE         = "-1";
    OLLAMA_NUM_PARALLEL       = "1";
    OLLAMA_MAX_LOADED_MODELS  = "1";
  };
};
```

---

## 3. GPU Clock Configuration

In `auto` DPM mode, the GPU boosts automatically to near-maximum clock (2845 MHz of 2900 MHz peak) during inference workloads. Forcing `power_dpm_force_performance_level=high` locks the clock at 2900 MHz (+2%) but increases idle power draw from ~99 W to ~140 W — a poor trade for a desktop with intermittent agent tasks.

**Do not set `power_dpm_force_performance_level=high`.** Leave DPM at `auto`.

`amdgpu.runpm=0` (already set in `boot.extraModprobeConfig`) prevents the GPU from entering deep sleep states between inference calls, which is sufficient to avoid the ROCm discovery timeout issue without pinning the clock.

Verify clock behaviour during inference:

```bash
watch -n1 'cat /sys/class/drm/card1/device/pp_dpm_sclk'
# Expected: highest clock entry marked with * during active inference
```

---

## 4. llama.cpp vs Ollama Performance

Measured on Strix Halo (Ryzen AI Max+ 395, 128 GB), 3-run averages, Vulkan backend unless noted:

| Model | Type | Backend | tok/s | Power |
|---|---|---|---|---|
| qwen3.5:35b-a3b | MoE (3.3B active) | Ollama ROCm | 40.38 | ~92 W |
| qwen3.5:35b-a3b | MoE (3.3B active) | Ollama Vulkan | 43.60 | ~78 W |
| qwen3.5:35b-a3b | MoE (3.3B active) | llama-bench ROCm | 45.33 | ~78 W |
| qwen3.5:35b-a3b | MoE (3.3B active) | llama-bench Vulkan | 57.48-58.56 | ~78 W |
| gemma4:e4b | Dense (4.5B eff.) | Ollama Vulkan | 34.19 | - |
| gemma4:e4b | Dense (4.5B eff.) | llama-bench Vulkan | 56.41 | - |
| qwen3.5:27b | Dense (27B) | Ollama Vulkan | 10.99 | ~97 W |
| qwen3.5:27b | Dense (27B) | llama-bench Vulkan | 11.91 | ~94 W |

MoE and small dense models show a 32-65% llama.cpp Vulkan advantage (qwen3.5:35b-a3b: +32%, gemma4:e4b: +65%). Large dense models show minimal gap (qwen3.5:27b: +8%) - at 27B parameters the workload is memory-bandwidth-bound on both backends; the bottleneck is LPDDR5X bandwidth, not inference overhead. Power draw consistently favours llama.cpp by 3-14 W at equivalent or higher clock speeds; qwen3.5:27b shows both backends near the TDP ceiling (~97 W Ollama vs ~94 W llama.cpp), with Ollama sustaining ~2865 MHz versus llama.cpp at 2900 MHz.

Switching the primary inference stack from Ollama to `llama-server` (Vulkan) is the highest-impact optimisation available on this hardware. The migration is a config-only change - no agent code changes are needed, as ZeroClaw connects via OpenAI-compatible API on either backend. Ollama would remain for model downloads and embedding serving. The migration path is tracked in README.md.

---

## 5. GTT Memory

The default TTM limit is ~50% of RAM (~64 GB on a 128 GB system). Expand to ~120 GB for LLM workloads:

```nix
# 120 GB expressed in 4 KiB pages: 120 * 1024^3 / 4096 = 31,457,280
boot.extraModprobeConfig = ''
  options ttm pages_limit=31457280
'';
```

`amdgpu.gttsize` is deprecated; use `ttm.pages_limit` only.

**BIOS UMA Frame Buffer Size** must be set to 512 MB (see section 6). The default may reserve up to 97 GB of RAM for the GPU framebuffer, leaving only 31 GB for the OS. The GPU dynamically claims compute memory via TTM — the BIOS carve-out is not needed for inference.

**Registry `vram` field:** The registry has `vram = 96` for Strix Halo hosts (e.g., Skrye and Zannah). With TTM expanded to ~120 GB, effective inference memory is ~112-120 GB. The `vram` registry value represents the conservative inference budget used by the Ollama mixin for model tier selection, not physical memory capacity.

---

## 6. BIOS Configuration

Current BIOS: version 3.04 (2025-11-19). Update via LVFS: `fwupdmgr update`.

| Setting | Value | Notes |
|---|---|---|
| UMA Frame Buffer Size | 512 MB | Critical. Default may reserve up to 97 GB for GPU, leaving only 31 GB for OS. BIOS path: Advanced → AMD CBS → NBIO → GFX Configuration. |
| TDP / Power Mode | 85-120 W | 85 W achieves ~97% of 120 W LLM performance. 120 W matters for dense CPU workloads. |

---

## 7. Linux Configuration

### IOMMU

Use `iommu=pt` (pass-through mode). AMD ROCm engineers explicitly advise against disabling IOMMU entirely. Pass-through reduces DMA overhead without disabling protection.

```nix
boot.kernelParams = [ "iommu=pt" ];
```

Do not use `amd_iommu=off`.

### amdgpu module parameters

`runpm=0` disables runtime power management, preventing the GPU from entering sleep states between inference calls (which causes ROCm discovery timeouts). Safe on a desktop.

```nix
boot.extraModprobeConfig = ''
  options amdgpu runpm=0
'';
```

### Kernel and firmware requirements

| Requirement | Minimum version |
|---|---|
| Kernel (gfx1151 + ROCm 7.2 stability) | 6.18.4 |
| linux-firmware | 20260110 |

NixOS 25.11 ships `pkgs.linuxPackages_latest` at 6.19.x — this satisfies the kernel requirement.

**linux-firmware 20251125 breaks ROCm on Strix Halo.** Verify the firmware package version in your nixpkgs pin is ≥ 20260110.

---

## 8. NixOS Configuration

### Additions to the Ollama mixin

The environment variables from section 2 belong in the `services.ollama` block inside `nixos/_mixins/server/ollama/default.nix`. No other changes are needed to that file.

### Hardware settings (host config or hardware mixin)

These settings are hardware-specific and belong in a host-level config or a dedicated hardware mixin, not in the Ollama service mixin:

```nix
{ config, lib, pkgs, ... }:

{
  # Kernel 6.19.x satisfies the ≥ 6.18.4 requirement for gfx1151 + ROCm 7.2.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "iommu=pt"  # Pass-through mode; do not use amd_iommu=off.
  ];

  boot.extraModprobeConfig = ''
    # Disable runtime power management to prevent GPU clock gating between inference calls.
    options amdgpu runpm=0
    # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
    options ttm pages_limit=31457280
  '';
}
```

### Monitoring

`amd-smi` reports all metrics as N/A on gfx1151 (ROCm/ROCm issue #6035). Use sysfs directly:

```bash
# GPU clock and active frequency
cat /sys/class/drm/card1/device/pp_dpm_sclk

# Performance level (should read "auto")
cat /sys/class/drm/card1/device/power_dpm_force_performance_level

# GPU utilisation
cat /sys/class/drm/card1/device/gpu_busy_percent

# Power draw (milliwatts)
cat /sys/class/hwmon/hwmon*/power1_average
```

---

## 9. NPU (XDNA2) - Future Consideration

The Ryzen AI Max+ 395 includes 40 XDNA2 neural processing units — dedicated silicon for matrix operations, separate from the iGPU.

**Current state (April 2026):**

- **llama.cpp:** no upstream NPU backend. A community fork by BrandedTamarasu-glitch (March 2026) dispatches GEMM ops via `mlir-aie` xclbins and XRT 2.21.75, achieving 43.7 tok/s on Llama-3.1-8B Q4_K_M at 0.947 J/tok — matching Vulkan iGPU decode speed while drawing ~10 W less. Not merged upstream.
- **Ollama:** no NPU support. Two open feature requests (issues #5186 and #11199) with 100+ upvotes each, no roadmap.
- **Linux driver:** `amdxdna` landed in kernel 6.14 (mainline). Userspace requires XRT + xrt-plugin-amdxdna shim; custom NixOS packaging would be needed.

**Why not now:** The NPU and iGPU share the LPDDR5X memory bus. For large memory-bound models, neither can exceed the bus throughput — the NPU cannot outperform what Vulkan iGPU already delivers.

**Why it matters later:** The NPU and iGPU are separate compute units. Once tooling matures, both can run concurrently — the NPU serving the embedding model while the iGPU handles generation, eliminating the current serialisation where embedding requests stall generation. The sub-1 J/tok efficiency figure also becomes meaningful for unattended overnight agent workloads.

**Trigger to revisit:** `ggml-hsa` merging into llama.cpp upstream, or llama-server gaining explicit NPU backend support.

---

## 10. Key References

| Resource | URL |
|---|---|
| AMD RDNA3.5 system optimisation (ROCm docs) | https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html |
| Ollama GEMV fusion buffer overlap bug (#15261) | https://github.com/ollama/ollama/issues/15261 |
| Ollama ROCm working guide for Strix Halo (#14855) | https://github.com/ollama/ollama/issues/14855 |
| ROCm/ROCm gfx1151 amd-smi N/A issue (#6035) | https://github.com/ROCm/ROCm/issues/6035 |
| Framework community VRAM allocation | https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081 |
| NixOS ollama module source | https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/ollama.nix |
| Power modes performance guide | https://strixhalo-homelab.d7.wtf/Guides/Power-Modes-and-Performance |
