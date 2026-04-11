# Strix Halo Performance Configuration

> AMD Ryzen AI Max+ 395 (gfx1151, RDNA3.5) · 128 GB LPDDR5X · Framework Desktop · Ollama 0.20.2 on NixOS 25.11

---

## 1. Ollama Backend: ROCm

Use `pkgs.ollama-rocm`. The existing Ollama mixin selects this automatically when `host.gpu.compute.acceleration = "rocm"`.

**Vulkan is not recommended for Strix Halo.** Two unfixed issues affect Ollama 0.20.2:

- iGPU VRAM detection is unreliable on the Vulkan path (~8 GB visible vs full unified memory on ROCm).
- MoE models (including `gemma4:e4b`) produce garbled output due to a buffer overlap bug in GEMV fusion (Ollama issue [#15261](https://github.com/ollama/ollama/issues/15261), unfixed as of 0.20.2).

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
  package = ollamaPackage;
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

## 4. GTT Memory

The default TTM limit is ~50% of RAM (~64 GB on a 128 GB system). Expand to ~120 GB for LLM workloads:

```nix
# 120 GB expressed in 4 KiB pages: 120 * 1024^3 / 4096 = 31,457,280
boot.extraModprobeConfig = ''
  options ttm pages_limit=31457280
'';
```

`amdgpu.gttsize` is deprecated; use `ttm.pages_limit` only.

**BIOS UMA Frame Buffer Size** must be set to 512 MB (see section 5). The default may reserve up to 97 GB of RAM for the GPU framebuffer, leaving only 31 GB for the OS. The GPU dynamically claims compute memory via TTM — the BIOS carve-out is not needed for inference.

**Registry `vram` field:** The registry has `vram = 96` for Strix Halo hosts (e.g., Skrye and Zannah). With TTM expanded to ~120 GB, effective inference memory is ~112–120 GB. The `vram` registry value represents the conservative inference budget used by the Ollama mixin for model tier selection, not physical memory capacity.

---

## 5. BIOS Configuration

Current BIOS: version 3.04 (2025-11-19). Update via LVFS: `fwupdmgr update`.

| Setting | Value | Notes |
|---|---|---|
| UMA Frame Buffer Size | 512 MB | Critical. Default may reserve up to 97 GB for GPU, leaving only 31 GB for OS. BIOS path: Advanced → AMD CBS → NBIO → GFX Configuration. |
| TDP / Power Mode | 85–120 W | 85 W achieves ~97% of 120 W LLM performance. 120 W matters for dense CPU workloads. |

---

## 6. Linux Configuration

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

## 7. NixOS Configuration

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

## 8. Key References

| Resource | URL |
|---|---|
| AMD RDNA3.5 system optimisation (ROCm docs) | https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html |
| Ollama GEMV fusion buffer overlap bug (#15261) | https://github.com/ollama/ollama/issues/15261 |
| Ollama ROCm working guide for Strix Halo (#14855) | https://github.com/ollama/ollama/issues/14855 |
| ROCm/ROCm gfx1151 amd-smi N/A issue (#6035) | https://github.com/ROCm/ROCm/issues/6035 |
| Framework community VRAM allocation | https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081 |
| NixOS ollama module source | https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/ollama.nix |
| Power modes performance guide | https://strixhalo-homelab.d7.wtf/Guides/Power-Modes-and-Performance |
