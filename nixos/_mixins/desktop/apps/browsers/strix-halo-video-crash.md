# Strix Halo: Chromium video-acceleration GPU hang

Reference document for the `strix-halo` host tag and the
`--disable-accelerated-video-decode --disable-accelerated-video-encode`
workaround applied to Chromium-family browsers (Brave, Google Chrome,
Microsoft Edge, Wavebox) on hosts with that tag.

Source evidence captured 2026-05-04 ~14:10 BST on `skrye`, after a hard
reboot triggered by playing an embedded video in a GitHub README in
Brave. Hardware: Framework Desktop with AMD Ryzen AI Max 300 ("Strix
Halo", Radeon 8060S iGPU). Kernel 7.0.2 NixOS, BIOS 03.05 (2026-01-21).
The same fault has been observed on `zannah`.

## What stands out

- **GPU SMU stopped responding at 13:57:38**, exactly the same second `hypridle` recorded a "Video Wake Lock" inhibitor coming in from the Brave process (`brave-1.89.143`). Repeated `SMU: No response msg_reg: 32 resp_reg: 0` from then on.
- **AMDGPU `vpe` (Video Processing Engine) ring timeout at 13:58:26**, followed by `GPU reset begin!` and a kernel `WARNING` in `dcn35_smu_send_msg_with_param` during the reset path.
- **Reboot was user-initiated, not a kernel panic**: `systemd-logind: Power key pressed short.` at 13:59:21, ~1m43s after the SMU first failed to respond. systemd ran a graceful shutdown sequence; this confirms the kernel was still alive but the display/GPU was hung.
- **AMDGPU device coredump was created at 13:58:26** (`/sys/class/drm/card1/device/devcoredump/data`), but it has already been **drained / aged out** — `devcoredump` directory is no longer present. Window for capturing it has closed.
- **A Brave/Chromium minidump was written at 13:58** (`Crash Reports/completed/e7ebee33-cabe-4703-a87e-606750bb5108.dmp`, 513 KB) — this is from the GPU process / renderer reacting to the hung GPU, not the cause.
- **No OOM killer activity, no kernel panic, no segfault chain leading up to the GPU hang** (one unrelated `[pango] fontcon` segfault appears at 13:59:21, after services started tearing down on the user-initiated power-off).
- IP block `vpe_v6_1_0` is the AMD VPE (Video Processing Engine) used for hardware video acceleration — exactly the path Brave/Chromium would touch when decoding/scaling an embedded `<video>` element with VA-API.
- Boot uses `amdgpu.ppfeaturemask=0xfff7ffff` (overdrive enabled, kernel taints `S` "CPU_OUT_OF_SPEC"). Note: kernel logs say *"Overdrive is enabled, please disable it before reporting any bugs unrelated to overdrive."*
- Kernel taint also includes `O` from the `v4l2loopback` and `ProCapture` out-of-tree modules.

## Trigger correlation: video playback to GPU hang

Martin clicked play on an embedded video in a GitHub README, viewed in Brave on `skrye`, at ~13:57:37 BST. The display froze within seconds; the kernel did not panic, and recovery required a power-button hold. The Brave dbus signal and the first AMDGPU SMU timeout share the same wall-clock second, and the failing IP block is the AMD Video Processing Engine (VPE) -- exactly the hardware path Chromium engages for hardware-accelerated `<video>` decode and scaling.

| Time (BST) | Layer | Event |
|------------|-------|-------|
| 13:57:37 | user | Brave used to play embedded video in GitHub README |
| 13:57:38 | brave/dbus | `Video Wake Lock` ScreenSaver inhibitor raised by `brave-1.89.143` |
| 13:57:38 | amdgpu | `SMU: No response msg_reg: 32 resp_reg: 0`; `Failed to power gate VPE!`; `DPM disable vpe failed, ret = -62` |
| 13:57:38+ | amdgpu | SMU "No response" repeats every ~5s; `Failed to disable gfxoff` / `Failed to retrieve enabled ppfeatures` cascade |
| 13:58:26 | amdgpu | `ring vpe timeout, signaled seq=216154, emitted seq=216158`; `GPU reset begin!`; device coredump created |
| 13:59:21 | user | Power key pressed short -- system alive, display wedged |
| 13:59:27 | amdgpu | `WARN` in `dcn35_smu_send_msg_with_param` during reset path (SMU still unresponsive) |
| 13:59:28 | systemd | Boot -1 last journal entry |

Causal chain in one line: video element played in Brave -> Chromium engaged hardware video decode/scaling on AMD VPE -> VPE-related SMU message timed out -> power-gate operations failed -> VPE ring timed out -> GPU reset attempted but SMU was already wedged -> display unrecoverable, user-initiated reboot.

This is a hardware-correlated fault on Strix Halo (dcn35 / `vpe_v6_1_0`), reproduced on both `skrye` and `zannah`. It was previously misattributed to Wavebox during Google Meet calls, where blanket `--disable-gpu` masked it. Brave hits the identical fault path because it engages the same hardware video acceleration. This correlation is the rationale for the `strix-halo` host tag and the `--disable-accelerated-video-decode --disable-accelerated-video-encode` workaround applied to Chromium-family browsers in this repo.

## Upstream bug correlation

Searched 2026-05-04 against drm-amd GitLab, freedesktop amd-gfx and dri-devel archives, kernel.org bugzilla, Ubuntu Launchpad, GitHub (Brave, ROCm, Framework community), and Phoronix. Confidence labels: **strong** = same function or VPE failure mode plus same hardware family plus video-related trigger; **partial** = same function or VPE behaviour, different context; **adjacent** = Strix Halo / dcn35 issues that inform the picture but are not this bug.

### Strong matches

| Source | URL | Date | Signature element matched |
|---|---|---|---|
| Ubuntu LP #2148686 "FrameworkDesktop: System randomly hangs after using Chrome (YouTube or Screen-Sharing)" | https://bugs.launchpad.net/bugs/2148686 | 2026-04-17 | Same hardware (Framework Desktop, Ryzen AI Max+ 395), same trigger (Chrome video / screen share), identical kernel sequence: `SMU: I'm not done with your previous command` -> `Failed to power gate VPE!` -> `Dpm disable vpe failed, ret = -62` -> `Failed to disable gfxoff` cascade -> `ring sdma0 timeout` -> `GPU reset begin!` -> `MES failed to respond to msg=REMOVE_QUEUE`. Reported on kernel 6.17.0-22-generic. Status: New, no fix linked. |
| drm-amd issue #4615 "VPE DPM stuck at higher level after short workloads" (Strix Halo) | https://gitlab.freedesktop.org/drm/amd/-/issues/4615 | 2025-10 | Reported by Sultan Alsawaf; root cause traced to VPE microcode keeping DPM at higher level when gated within 1 s of a short workload, causing SMU to wedge on `PowerDownVpe(50)`. Closed by upstream commit `3ac635367eb5` (see "Upstream fixes" below). |
| brave/brave-browser #54465 "Linux/Wayland (Hyprland, AMD): full system freeze when pausing/stopping YouTube" | https://github.com/brave/brave-browser/issues/54465 | 2026-04-13 | Strix Halo iGPU `1002:1586`, kernel 6.19.11, Brave on Wayland, freeze on YouTube pause/stop. Status: open. |

### Partial matches

| Source | URL | Date | Relevance |
|---|---|---|---|
| Antheas Kapenekakis, "[PATCH v1] drm/amdgpu/vpe: increase VPE_IDLE_TIMEOUT to fix hang on Strix Halo" | https://lists.freedesktop.org/archives/dri-devel/2025-August/521491.html | 2025-08 | Identical signature (`Failed to power gate VPE!`, `Dpm disable vpe failed, ret = -62`, `SMU: I'm not done with your previous command: SMN_C2PMSG_66:0x00000032`) on Asus Z13 Strix Halo. Suspend/resume trigger rather than video, but same race: VPE gated before DPM settled. Superseded by issue #4615 fix. |
| Framework Community, "AMD Drivers Frequently Hanging and Crashing - Framework Desktop" | https://community.frame.work/t/amd-drivers-frequently-hanging-and-crashing/79270 | 2025-12-30 | Framework Desktop 64GB, repeated amdgpu hangs watching videos in Firefox. Tested kernels 6.16, 6.18, LTS, Zen, multiple distros (Arch, Fedora 43, Ubuntu, NixOS), `amdgpu.mes=0`; nothing fully resolved. No upstream fix referenced. |
| ROCm/ROCm #5665 "Strix Halo + Sunshine HW encoding -> GPU hang, VRAM Loss" | https://github.com/ROCm/ROCm/issues/5665 | 2025-11-14 | `resume of IP block <vpe_v6_1> failed -110`, MES wedge under VPE encode load. Different trigger (Sunshine + ROCm), same VPE / MES failure family. Workaround: software encode (libx264). |

### Adjacent (Strix Halo / dcn35 context, not this exact bug)

| Source | URL | Notes |
|---|---|---|
| 1bit-systems #1 "amdgpu OPTC CRTC hang on Strix Halo (gfx1151)" | https://github.com/bong-water-water-bong/1bit-systems/issues/1 | Same `SMU mailbox -> VPE/VCN powergate fail -> dcn35` cascade, but trigger is sustained ROCm compute, not video. Author reports rolling back to 6.18.22-lts eliminates the sustained freeze. |
| Bugzilla #220812 / commit `3925683515e9` | https://bugzilla.kernel.org/show_bug.cgi?id=220812 | Revert of "drm/amd: Skip power ungate during suspend for VPE" (commit `2a6c826cfeed`) merged 2025-12-02 after it triggered `VPE queue reset failed` regressions. Worth knowing if a kernel between mid-November and early December lands. |
| linux-firmware MES 0x83 regression on Strix Halo | https://github.com/ROCm/ROCm/issues/5724 | Affects gfx1151 broadly. Reverted upstream 2025-12-01 to 0x80. Verify `cat /sys/kernel/debug/dri/*/amdgpu_firmware_info \| grep MES` shows feature version 1, firmware 0x80. |

### Upstream fix status

- **Landed**: commit `3ac635367eb5` "drm/amd: Check that VPE has reached DPM0 in idle handler" (Mario Limonciello, AMD) closes drm-amd #4615. Gated to `IP_VERSION(6, 1, 1)` (Strix Halo VPE) and PMFW `< 0x0a640500`. Cherry-picked with `Cc: stable@vger.kernel.org`, so it should reach 6.18-stable and 6.17-stable streams. The signature this address is the closest published match to ours.
- **In flight / churn**: a separate path via `amdgpu_device_set_pg_state` skipping VPE ungate during suspend was merged then reverted (commits `2a6c826cfeed` / `31ab31433c9b` then revert `3925683515e9`, late November / early December 2025). The s2idle issue that prompted it is being deferred to BIOS.
- **Confidence this is our bug**: the LP #2148686 signature is byte-for-byte ours (same `msg_reg: 32 resp_reg: 0`, same `Failed to power gate VPE!`, same `ret = -62`, same Framework Desktop hardware, same Chrome-video trigger). Drm-amd #4615 fix is the most likely upstream resolution, although the original #4615 trigger was a ring-test ungate-then-gate race rather than active video decode; the underlying mechanism (VPE gated while DPM not at 0, SMU wedges on `PowerDownVpe(50)`) is the same.

### Workarounds others are using

| Workaround | Source | Tried here |
|---|---|---|
| Disable Chromium hardware video decode/encode (`--disable-accelerated-video-decode --disable-accelerated-video-encode`) | implicit across LP #2148686, brave #54465, Framework community thread | yes, this repo |
| Pin GPU to high perf via `power_dpm_force_performance_level=high` | 1bit-systems #1 | no; reduces but does not close window |
| Roll back to 6.18-LTS (avoid the brief revert window in late 2025 mainline) | 1bit-systems #1, Framework community | no |
| `amdgpu.cwsr_enable=0` (boot param) | ROCm #5724 | no; targets MES/CWSR, orthogonal to VPE-DPM bug |
| `amdgpu.mes=0` | Framework Community thread | tried, no improvement reported there |
| Verify MES firmware is **0x80**, not 0x83 | ROCm #5724 | not yet verified on `skrye` / `zannah` |

### Action implied

Once kernel 6.18-stable or 6.17-stable carrying commit `3ac635367eb5` is in nixpkgs and on `skrye` / `zannah`, plus a current `linux-firmware` (MES feature 1 firmware 0x80, not 0x83), the `--disable-accelerated-video-*` workaround can be re-evaluated. Track the next reproduction with `cat /sys/kernel/debug/dri/*/amdgpu_firmware_info | grep -E 'MES|VPE|SMU'` recorded so that fix presence can be confirmed.

### Status on skrye (2026-05-04)

- **MES firmware 0x86: good for the 0x83 regression class.** Upstream `linux-firmware 20260410` ships `gc_11_5_0_mes_2.bin` reporting MES feature 1 firmware `0x00000086`, and the reporter on ROCm/ROCm#6165 (Strix Halo, 2026-04-20) states the "MES 0x83 page-fault class was resolved for us by upgrading to MES 0x86" ([github.com/ROCm/ROCm/issues/6165](https://github.com/ROCm/ROCm/issues/6165)). 0x86 supersedes the 0x80 baseline cleanly, with no fresh revert in linux-firmware between `20260309` and `20260410` ([gitlab.com/kernel-firmware/linux-firmware tag 20260410](https://gitlab.com/kernel-firmware/linux-firmware/-/commits/main)). A *distinct* silent-hang under sustained compute remains under triage on 0x86, but it has a different signature (no SMU timeout, no GPU reset, no kernel log) and is unrelated to our VPE/SMU cascade.
- **Kernel 7.0.2 contains commit `3ac635367eb5`.** The patch landed via the `amd-drm-fixes-6.18-2025-10-29` pull and merged before Linus tagged Linux 6.18 on 2025-11-30 ([lwn.net/Articles/1048823/](https://lwn.net/Articles/1048823/)). It carries `Cc: stable@vger.kernel.org`, has been picked up to 6.17.y and 6.18.y stable, and is in the 7.0 base tagged 2026-04-12 ([github.com/torvalds/linux commit 028ef9c9](https://github.com/torvalds/linux/commit/028ef9c96e96197026887c0f092424679298aae8)). `skrye`'s `7.0.2 #1-NixOS` (built 2026-04-27) therefore has the fix. Confirm with `git -C /path/to/linux log --oneline v7.0.2 -- drivers/gpu/drm/amd/amdgpu/amdgpu_vpe.c` if precise verification is wanted.
- **PMFW threshold `0x0a640500` decoded.** `adev->pm.fw_version` is the SMU / PMFW (Power Management Firmware) version, decoded as program.major.minor.debug = `0x0a.0x64.0x05.0x00` = "10.100.5.0". This firmware ships in the BIOS/AGESA capsule (Insyde + StrixHaloPI-FP11 PI), not in linux-firmware. Reference data points: BIOS 03.04 (2025-11-19) reports PMFW `0x0a640600` per ROCm/ROCm#6165, and a Z13 Strix Halo on AGESA `StrixHaloPI-FP11 1.0.0.0c` reports `smu_fw_version:100.112.0` = `0x0a700000` ([dri-devel 2025-08 thread](https://lists.freedesktop.org/archives/dri-devel/2025-August/521491.html)). Both are above the `0x0a640500` threshold, so the kernel workaround in `vpe_need_dpm0_at_power_down()` returns `false` and is a no-op. `skrye` on BIOS 03.05 (2026-01-21) is newer than 03.04 and therefore almost certainly already at or above `0x0a640500`. Verify on `skrye` with `cat /sys/bus/platform/drivers/amd_pmc/*/smu_fw_version`.
- **Bottom line.** `skrye`'s kernel and BIOS already satisfy both halves of the upstream remedy (PMFW is past the threshold so the VPE-DPM0 race cannot fire; the 7.0.2 kernel carries the workaround anyway as belt-and-braces), and a `linux-firmware` bump to `20260410` lifts MES to 0x86, which closes the related MES regression class. The Chromium `--disable-accelerated-video-*` workaround should still be kept on for now until `linux-firmware` is bumped to `20260410` *and* one clean reproduction attempt confirms the fault no longer triggers, since LP #2148686 remains open with no upstream fix linked and ROCm #6165 shows a new compute-load hang still under investigation.

## Boot index

```
journalctl --list-boots
 -1 af4e68f3c117457cbdf20b753f1c4b43 Thu 2024-12-19 21:27:50 GMT Mon 2026-05-04 13:59:28 BST   # crashed boot
  0 025029ca1c2846a3aa99fb0973022544 Thu 2024-12-19 21:27:50 GMT Mon 2026-05-04 14:07:50 BST   # current
```

The "First Entry" date of 2024-12-19 is the persistent journal head; relevant timestamps are the "Last Entry" (boot -1 ended at **13:59:28 BST**) and current boot's beginning shortly after.

## Hardware / driver state (current boot)

```
$ uname -a
Linux skrye 7.0.2 #1-NixOS SMP PREEMPT_DYNAMIC Mon Apr 27 13:30:19 UTC 2026 x86_64 GNU/Linux

$ lspci -k | grep -A3 VGA
c9:00.0 Display controller: Advanced Micro Devices, Inc. [AMD/ATI] Strix Halo [Radeon Graphics / Radeon 8050S Graphics / Radeon 8060S Graphics] (rev c1)
	Subsystem: Framework Computer Inc. Device 000a
	Kernel driver in use: amdgpu
	Kernel modules: amdgpu

$ lsmod | grep -iE 'nvidia|nouveau|amdgpu|i915'
amdgpu              17080320  65
amdxcp                 12288  1 amdgpu
i2c_algo_bit           24576  1 amdgpu
drm_ttm_helper         20480  2 amdgpu
ttm                   126976  2 amdgpu,drm_ttm_helper
drm_exec               16384  1 amdgpu
drm_panel_backlight_quirks    12288  1 amdgpu
gpu_sched              69632  2 amdxdna,amdgpu
drm_suballoc_helper    16384  1 amdgpu
video                  81920  1 amdgpu
drm_buddy              32768  1 amdgpu
drm_display_helper    327680  9 amdgpu
cec                    81920  2 drm_display_helper,amdgpu
```

No NVIDIA or i915 drivers in play. AMD-only stack: `amdgpu`, `amdxdna` (XDNA NPU), `amdxcp`.

### Kernel command line (relevant flags)

```
amd_pstate=active usbcore.autosuspend=-1 amdgpu.ppfeaturemask=0xfff7ffff threadirqs quiet loglevel=3
mitigations=off lsm=landlock,yama,bpf
```

### AMDGPU IP blocks initialised at boot

```
detected ip block number 0  <common_v1_0_0> (soc21_common)
detected ip block number 1  <gmc_v11_0_0>  (gmc_v11_0)
detected ip block number 2  <ih_v6_0_0>    (ih_v6_1)
detected ip block number 3  <psp_v13_0_0>  (psp)
detected ip block number 4  <smu_v14_0_0>  (smu)
detected ip block number 5  <dce_v1_0_0>   (dm)
detected ip block number 6  <gfx_v11_0_0>  (gfx_v11_0)
detected ip block number 7  <sdma_v6_0_0>  (sdma_v6_0)
detected ip block number 8  <vcn_v4_0_5>   (vcn_v4_0_5)
detected ip block number 9  <jpeg_v4_0_5>  (jpeg_v4_0_5)
detected ip block number 10 <mes_v11_0_0>  (mes_v11_0)
detected ip block number 11 <vpe_v6_1_0>   (vpe_v6_1)         <-- ring that timed out
detected ip block number 12 <isp_v4_1_1>   (isp_ip)
amdgpu 0000:c9:00.0: VPE: collaborate mode true
amdgpu 0000:c9:00.0: [drm] Display Core v3.2.369 initialized on DCN 3.5.1
amdgpu 0000:c9:00.0: [drm] DMUB hardware initialized: version=0x09004100
[VCN instance 0] Found VCN firmware Version ENC: 1.24 DEC: 9 VEP: 0 Revision: 16
[VCN instance 1] Found VCN firmware Version ENC: 1.24 DEC: 9 VEP: 0 Revision: 16
amdgpu 0000:c9:00.0: SMU is initialized successfully!
amdgpu 0000:c9:00.0: Overdrive is enabled, please disable it before reporting any bugs unrelated to overdrive.
```

## Brave / Video activity in the prior boot

The only Brave-related signal in the prior-boot journal:

```
May 04 13:57:38 skrye hypridle[4122]: [LOG] ScreenSaver inhibit: true dbus message from
  /nix/store/jqblispkl5iy214w0k8qxmjrn7z3crr5-brave-1.89.143/opt/brave.com/brave/brave
  (owner: :1.176) with content Video Wake Lock
```

`brave 1.89.143`. The wake-lock dbus message arrives the same second the AMDGPU SMU stopped responding (next section). No earlier Brave process start logged in this boot — it had been running long enough to predate `journalctl -b -1`'s retained scope for systemd unit start lines, but its scope is still reflected in the post-crash CPU/memory accounting (`app-org.chromium.Chromium-25285.scope: Consumed 10min 33.356s CPU time, 65.7M memory peak.`).

(The earlier Chromium scopes like `25285`, `140482`, `3562316` are from May 2 and May 3 — Chromium proper, not Brave.)

## Kernel timeline of the GPU hang (boot -1, kernel ring)

Source: `journalctl -k -b -1`. Filtered for relevance.

```
May 04 13:57:38 skrye kernel: amdgpu 0000:c9:00.0: SMU: No response msg_reg: 32 resp_reg: 0
May 04 13:57:38 skrye kernel: in params:00000000
May 04 13:57:38 skrye kernel: amdgpu 0000:c9:00.0: Failed to power gate VPE!
May 04 13:57:38 skrye kernel: amdgpu 0000:c9:00.0: [drm] *ERROR* DPM disable vpe failed, ret = -62.
May 04 13:57:40 skrye kernel: amdgpu 0000:c9:00.0: Dumping IP State
May 04 13:57:43 skrye kernel: amdgpu 0000:c9:00.0: SMU: No response msg_reg: 32 resp_reg: 0
May 04 13:57:43 skrye kernel: amdgpu 0000:c9:00.0: Failed to power gate VCN instance 0!
May 04 13:57:43 skrye kernel: amdgpu 0000:c9:00.0: [drm] *ERROR* DPM disable vcn failed, ret = -62.
May 04 13:57:48 skrye kernel: amdgpu 0000:c9:00.0: Failed to disable gfxoff!
May 04 13:57:54 skrye kernel: amdgpu 0000:c9:00.0: Failed to retrieve enabled ppfeatures!
May 04 13:57:59 skrye kernel: amdgpu 0000:c9:00.0: Failed to retrieve enabled ppfeatures!
May 04 13:58:05 skrye kernel: amdgpu 0000:c9:00.0: Failed to disable gfxoff!
May 04 13:58:10 skrye kernel: amdgpu 0000:c9:00.0: Failed to retrieve enabled ppfeatures!
May 04 13:58:15 skrye kernel: amdgpu 0000:c9:00.0: Failed to retrieve enabled ppfeatures!
May 04 13:58:21 skrye kernel: amdgpu 0000:c9:00.0: Failed to disable gfxoff!
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: Failed to disable gfxoff!
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: Dumping IP State Completed
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: [drm] AMDGPU device coredump file has been created
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: [drm] Check your /sys/class/drm/card1/device/devcoredump/data
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: ring vpe timeout, signaled seq=216154, emitted seq=216158
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: GPU reset begin!. Source:  1
May 04 13:58:27 skrye kernel: amdgpu 0000:c9:00.0: Register(0) [regUVD_POWER_STATUS] failed to reach value 0x00000001 != 0x00000002n
May 04 13:58:27 skrye kernel: amdgpu 0000:c9:00.0: Register(0) [regUVD_RB_RPTR] failed to reach value 0x00000080 != 0x00000000n
May 04 13:58:27 skrye kernel: amdgpu 0000:c9:00.0: Register(0) [regUVD_POWER_STATUS] failed to reach value 0x00000001 != 0x00000002n
... (SMU "No response" repeats every ~5s through 13:59:03) ...
```

### Kernel WARNING / call trace during the GPU reset path

```
May 04 13:59:27 skrye kernel: ------------[ cut here ]------------
May 04 13:59:27 skrye kernel: WARNING: drivers/gpu/drm/amd/amdgpu/../display/dc/clk_mgr/dcn35/dcn35_smu.c:175 at dcn35_smu_send_msg_with_param+0x10d/0x1d0 [amdgpu], CPU#23: kworker/u128:2/3316950
May 04 13:59:27 skrye kernel: CPU: 23 UID: 0 PID: 3316950 Comm: kworker/u128:2 Tainted: G S         O        7.0.2 #1-NixOS PREEMPT(lazy)
May 04 13:59:27 skrye kernel: Tainted: [S]=CPU_OUT_OF_SPEC, [O]=OOT_MODULE
May 04 13:59:27 skrye kernel: Hardware name: Framework Desktop (AMD Ryzen AI Max 300 Series)/FRANMFCP06, BIOS 03.05 01/21/2026
May 04 13:59:27 skrye kernel: Workqueue: amdgpu-reset-dev drm_sched_job_timedout [gpu_sched]
May 04 13:59:27 skrye kernel: RIP: 0010:dcn35_smu_send_msg_with_param+0x10d/0x1d0 [amdgpu]
May 04 13:59:27 skrye kernel: RSP: 0018:ffffcc6b3df0b828 EFLAGS: 00010246
May 04 13:59:27 skrye kernel: RAX: 0000000000000000 RBX: ffff8a3dd9ff4000 RCX: 0000000000000017
May 04 13:59:27 skrye kernel: RDX: 0000000000007d82 RSI: 00000000000074f7 RDI: ffff8a3df019ff00
May 04 13:59:27 skrye kernel: RBP: 00000000ffffffff R08: 0000000000000000 R09: ffffcc6b3df0b7b0
May 04 13:59:27 skrye kernel: R10: 0000000000000001 R11: 0000000000001000 R12: 000000000000000d
May 04 13:59:27 skrye kernel: R13: 0000000000000000 R14: ffff8a3dd085ac80 R15: 00000000000012d8
May 04 13:59:27 skrye kernel: FS:  0000000000000000(0000) GS:ffff8a5cee84a000(0000) knlGS:0000000000000000
May 04 13:59:27 skrye kernel: CS:  0010 DS: 0000 ES: 0000 CR0: 0000000080050033
May 04 13:59:27 skrye kernel: CR2: 000000c037d4a010 CR3: 0000000defc24000 CR4: 0000000000f50ef0
May 04 13:59:27 skrye kernel: PKRU: 55555554
May 04 13:59:27 skrye kernel: Call Trace:
May 04 13:59:27 skrye kernel:  <TASK>
May 04 13:59:27 skrye kernel:  dcn35_smu_enable_pme_wa+0x23/0x60 [amdgpu]
May 04 13:59:27 skrye kernel:  link_set_dpms_off+0x122/0x6a0 [amdgpu]
May 04 13:59:27 skrye kernel:  dcn31_reset_hw_ctx_wrap+0x29d/0x5e0 [amdgpu]
May 04 13:59:27 skrye kernel:  dce110_apply_ctx_to_hw+0x66/0x2d0 [amdgpu]
May 04 13:59:27 skrye kernel:  dc_commit_state_no_check+0x6e5/0xec0 [amdgpu]
May 04 13:59:27 skrye kernel:  dc_commit_streams+0x31b/0x510 [amdgpu]
May 04 13:59:27 skrye kernel:  dm_suspend+0x231/0x290 [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_ip_block_suspend+0x27/0x40 [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_device_ip_suspend_phase1+0x9f/0x100 [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_device_pre_asic_reset+0xe6/0x310 [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_device_asic_reset+0x41/0x44d [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_device_gpu_recover.cold+0x252/0x2f2 [amdgpu]
May 04 13:59:27 skrye kernel:  amdgpu_job_timedout.cold+0x2c1/0x309 [amdgpu]
May 04 13:59:27 skrye kernel:  ? finish_task_switch.isra.0+0x95/0x2c0
May 04 13:59:27 skrye kernel:  drm_sched_job_timedout+0x7e/0x160 [gpu_sched]
May 04 13:59:27 skrye kernel:  process_one_work+0x198/0x3a0
May 04 13:59:27 skrye kernel:  worker_thread+0x177/0x2e0
May 04 13:59:27 skrye kernel:  ? __pfx_worker_thread+0x10/0x10
May 04 13:59:27 skrye kernel:  kthread+0xe2/0x110
May 04 13:59:27 skrye kernel:  ? __pfx_kthread+0x10/0x10
May 04 13:59:27 skrye kernel:  ret_from_fork+0x2ce/0x350
May 04 13:59:27 skrye kernel:  ? __pfx_kthread+0x10/0x10
May 04 13:59:27 skrye kernel:  ret_from_fork_asm+0x1a/0x30
May 04 13:59:27 skrye kernel:  </TASK>
May 04 13:59:27 skrye kernel: ---[ end trace 0000000000000000 ]---
```

This is a `WARN`, not an `Oops`/`BUG` — kernel didn't panic. The reset path tried to bring DCN35 SMU to send a message and got no response, same as everything else after 13:57:38. Note the sequence: `drm_sched_job_timedout` (job watchdog) → `amdgpu_job_timedout.cold` → `amdgpu_device_gpu_recover` → `amdgpu_device_asic_reset` → `amdgpu_device_pre_asic_reset` → `amdgpu_device_ip_suspend_phase1` → `dm_suspend` → display commit path → `dcn35_smu_send_msg_with_param` (warns).

`Modules linked in:` (full list, deduplicated):

```
cfg80211 rfcomm snd_seq_dummy snd_hrtimer snd_seq xt_mark fuse af_packet tun xt_MASQUERADE
nft_chain_nat qrtr xt_addrtype xfrm_user xfrm_algo xt_set ip_set_hash_net ip_set cmac
algif_hash algif_skcipher af_alg bnep xt_conntrack ip6t_rpfilter ipt_rpfilter xt_pkttype
xt_LOG nf_log_syslog xt_tcpudp nft_compat nf_tables typec_thunderbolt sch_fq_codel xt_nat
x_tables nf_nat nf_conntrack nf_defrag_ipv6 nf_defrag_ipv4 vhost_vsock
vmw_vsock_virtio_transport_common vhost vhost_iotlb vsock veth v4l2loopback(O) uinput loop
i2c_dev br_netfilter bridge stp llc atkbd libps2 vivaldi_fmap typec_displayport xfs
nls_iso8859_1 nls_cp437 vfat fat edac_mce_amd edac_core amd_atl intel_rapl_msr
intel_rapl_common r8153_ecm cdc_ether usbnet cros_ec_sysfs leds_cros_ec cros_ec_hwmon
cros_ec_chardev cros_ec_debugfs gpio_cros_ec led_class_multicolor spd5118 cros_ec_dev
btusb btrtl kvm_amd r8152 btintel btmtk btbcm mii kvm mousedev bluetooth irqbypass joydev
ghash_clmulni_intel ecdh_generic rapl wmi_bmof rfkill ecc snd_hda_codec_alc269
snd_hda_codec_realtek_lib efi_pstore sp5100_tco watchdog snd_hda_codec_atihdmi
snd_hda_scodec_component snd_hda_codec_generic snd_usb_audio snd_hda_codec_hdmi r8169
realtek snd_ump mdio_devres snd_usbmidi_lib of_mdio snd_rawmidi i2c_piix4 k10temp i2c_smbus
amdxdna amd_pmf snd_seq_device snd_hda_intel onboard_usb_dev fixed_phy amdtee fwnode_mdio
snd_hda_codec amd_sfh snd_hda_core platform_profile ucsi_acpi tiny_power_button libphy ccp
snd_intel_dspcfg rtc_cmos ac typec_ucsi snd_intel_sdw_acpi amd_pmc cros_ec_lpcs mdio_bus
snd_hwdep sha1 roles cros_ec button typec cros_ec_proto thermal serio evdev mac_hid
ProCapture(O) snd_pcm snd_timer snd soundcore videodev mc nfnetlink lz4 zram
842_decompress 842_compress lz4hc_compress lz4_compress dmi_sysfs dm_crypt encrypted_keys
trusted asn1_encoder tee btrfs libblake2b xor raid6_pq input_leds led_class dm_mod raid0
dax md_mod hid_generic usbhid sd_mod hid ahci amdgpu libahci nvme tpm_crb libata nvme_core
thunderbolt xhci_pci aesni_intel nvme_keyring scsi_mod xhci_hcd nvme_auth tpm_tis hkdf
tpm_tis_core scsi_common crc16 amdxcp i2c_algo_bit drm_ttm_helper ttm drm_exec
drm_panel_backlight_quirks gpu_sched drm_suballoc_helper video wmi drm_buddy
drm_display_helper cec efivarfs tpm rng_core autofs4
```

## Userspace timeline 13:59:21–13:59:28 (shutdown)

The system did **not** panic. systemd-logind logged a power-key press at 13:59:21 and ran a graceful shutdown which still managed to log services tearing down. Boot -1 last entry: `13:59:28 BST`.

```
May 04 13:59:21 skrye systemd-logind[1806]: Power key pressed short.
May 04 13:59:21 skrye systemd-logind[1806]: Powering off...
May 04 13:59:21 skrye systemd-logind[1806]: System is powering down.
May 04 13:59:21 skrye kmscon[130443]: [183439.322030] WARNING: seat: destroying seat seat0 while still awake: -16 ...
May 04 13:59:21 skrye systemd[1]: Stopping AMDGPU Control Daemon...
May 04 13:59:21 skrye lact[1780]: ERROR lact_daemon::server::gpu_controller::amd: could not get current performance level: io error: Device or resource busy (os error 16)
May 04 13:59:21 skrye systemd[1]: Stopped AMDGPU Control Daemon.
May 04 13:59:21 skrye dockerd[1911]: Daemon shutdown complete
May 04 13:59:21 skrye tailscaled[1924]: control: client.Shutdown ...
May 04 13:59:21 skrye make-initrd-ng[3428057]: /shutdown -> /nix/store/.../systemd-shutdown
... many "Stopping <unit>" / "Stopped <unit>" lines ...
May 04 13:59:26 skrye wl-paste[3428557]: Failed to connect to a Wayland server: Connection refused (Wayland session already torn down)
May 04 13:59:26 skrye systemd[3794]: cliphist.service: Main process exited, code=exited, status=1/FAILURE
May 04 13:59:26 skrye systemd[3794]: cliphist-images.service: Main process exited, code=exited, status=1/FAILURE
May 04 13:59:26 skrye systemd[3794]: avizo.service: Main process exited, code=exited, status=1/FAILURE
May 04 13:59:26 skrye systemd[3794]: waybar.service: Main process exited, code=exited, status=1/FAILURE
May 04 13:59:26 skrye python3.13[3428517]: This application failed to start because no Qt platform plugin could be initialized. (maestral-gui restart loop)
May 04 13:59:27 skrye kernel: ------------[ cut here ]------------     <-- the AMDGPU WARN above fires here
May 04 13:59:27 skrye kernel: WARNING: ... dcn35_smu_send_msg_with_param ...
May 04 13:59:27 skrye kernel: ---[ end trace 0000000000000000 ]---
May 04 13:59:28 skrye python3.13[3428641]: ... (last line in boot -1)
```

The `lact` "Device or resource busy" error confirms the GPU was wedged at shutdown time. Maestral-gui / waybar / cliphist / avizo failures at 13:59:26 are downstream — Wayland compositor went away as part of the user logout step, so user services restart-looping fail to reconnect.

One pre-shutdown segfault, unrelated to AMDGPU (different process tree, separate timing):

```
May 04 13:59:21 skrye kernel: [pango] fontcon[2889]: segfault at 76a92da1a935 ip 000076a92da1a935 sp 000076a92cb82c80 error 14 likely on CPU 13 (core 13, socket 0)
```

## Errors / warnings from prior boot at err..emerg

`journalctl -b -1 -p err..emerg` returned **20 873 lines**, almost all of which are pre-existing `pango` font cache warnings, `pam_unix` login coredumps from cron jobs, `nullmailer` queue errors, etc., spanning from 2026-04-30 onward. Nothing new in the `err` priority class is tied to the GPU hang itself; the GPU events came in at `kern.warn` level. A representative selection from the 13:55–14:00 window:

```
May 04 13:59:21 skrye lact[1780]: ERROR ... could not get current performance level: io error: Device or resource busy (os error 16)
May 04 13:59:26 skrye systemd-coredump[3428498]: Failed to send coredump datagram: Connection reset by peer
May 04 13:59:26 skrye systemd-coredump[3428559]: Failed to send coredump datagram: Broken pipe
May 04 13:59:27 skrye systemd[3794]: maestral-gui.service: Main process exited, code=dumped, status=6/ABRT
May 04 13:59:27 skrye systemd[3794]: cliphist.service: Failed with result 'exit-code'.
May 04 13:59:27 skrye systemd[3794]: avizo.service: Start request repeated too quickly.
May 04 13:59:27 skrye systemd[3794]: waybar.service: Start request repeated too quickly.
```

(Truncated: the full 20 873-line output is dominated by older, unrelated noise.)

## Coredumps captured

`coredumpctl list --since="2026-05-04 13:55"`:

```
TIME                         PID  UID GID SIG     COREFILE     EXE                                                                        SIZE
Mon 2026-05-04 14:01:07 BST 2992  995 995 SIGABRT inaccessible /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13    -
Mon 2026-05-04 14:01:08 BST 3199  995 995 SIGABRT inaccessible /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13    -
Mon 2026-05-04 14:01:08 BST 3316  995 995 SIGABRT inaccessible /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13    -
Mon 2026-05-04 14:01:09 BST 3366  995 995 SIGABRT inaccessible /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13    -
Mon 2026-05-04 14:01:09 BST 3481  995 995 SIGABRT inaccessible /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13    -
Mon 2026-05-04 14:01:20 BST 3846 1000 100 SIGABRT present      /nix/store/qwb5ygz9k8gs5ql9bpxbrsrv12r1icgm-python3-3.13.12/bin/python3.13   6M
```

All from the **current boot**, all `maestral_qt` (Maestral Dropbox client). These are the post-reboot Qt restart-loop crashes from the user service starting before its Wayland/X session was ready (uid 995 is the mpd / system-level python user before martin's session became available). **None of these are from the prior crashed boot** — coredumps captured during boot -1 itself are listed in the `coredumpctl` history but tied to the older boot ID `af4e68f3...` (see `/var/lib/systemd/coredump/` listing below).

### `/var/lib/systemd/coredump/` files relevant to the crash window

```
-rw-r-----+ 1 root root  6333394 May  4 14:01 core.\x2emaestral_qt-wr.1000.025029ca1c2846a3aa99fb0973022544.3846.1777899680000000.zst
-rw-r-----  1 root root  6328503 May  4 14:01 core.\x2emaestral_qt-wr.995.025029ca1c2846a3aa99fb0973022544.2992.1735689661000000.zst
-rw-r-----  1 root root  6324406 May  4 14:01 core.\x2emaestral_qt-wr.995.025029ca1c2846a3aa99fb0973022544.3199.1777899668000000.zst
-rw-r-----  1 root root  6330590 May  4 14:01 core.\x2emaestral_qt-wr.995.025029ca1c2846a3aa99fb0973022544.3316.1777899668000000.zst
-rw-r-----  1 root root  6329703 May  4 14:01 core.\x2emaestral_qt-wr.995.025029ca1c2846a3aa99fb0973022544.3366.1777899669000000.zst
-rw-r-----  1 root root  6324743 May  4 14:01 core.\x2emaestral_qt-wr.995.025029ca1c2846a3aa99fb0973022544.3481.1777899669000000.zst
```

Boot ID `025029ca1c2846a3aa99fb0973022544` is the **current** boot; these are the post-reboot Maestral churn, not from the crashed boot.

The `af4e68f3...` (crashed-boot) coredumps in this directory are all from `/nix/store/.../shadow-4.18.0/bin/login` — pre-existing PAM/login SIGQUIT coredumps from cron-driven login attempts, not GPU-related. Listing summary:

- ~120 × `core.login.0.af4e68f3...` (root login SIGQUIT, shadow-4.18.0, all "inaccessible") — long-running pattern unrelated to the crash
- 4 × `core.\x2emaestral_qt-wr.995.af4e68f3...` and 1 × `core.\x2emaestral_qt-wr.1000.af4e68f3...` from earlier in May 2 (also unrelated)
- **No GPU/amdgpu/Brave/Chromium coredump** captured in `/var/lib/systemd/coredump/` from the crashed boot

## AMDGPU device coredump

The kernel announced one was created:

```
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: [drm] AMDGPU device coredump file has been created
May 04 13:58:26 skrye kernel: amdgpu 0000:c9:00.0: [drm] Check your /sys/class/drm/card1/device/devcoredump/data
```

Current state: `ls /sys/class/drm/card1/device/devcoredump/` → `No such file or directory`. The devcoredump has been read (consumed) or reached its 5-minute auto-expiry. The data is gone. (For next time: `cat /sys/class/drm/card1/device/devcoredump/data > /tmp/amdgpu-devcoredump.bin` immediately after the GPU reset notification.)

## Brave / Chromium browser-side crash artefacts

```
$ ls -la "/home/martin/.config/BraveSoftware/Brave-Browser/Crash Reports/completed/"
total 508
-rw------- 1 martin users 513392 May  4 13:58 e7ebee33-cabe-4703-a87e-606750bb5108.dmp
-rw------- 1 martin users     32 May  4 13:58 e7ebee33-cabe-4703-a87e-606750bb5108.meta
```

The `.meta` file is binary/serialised Crashpad metadata (not human-readable). The `.dmp` is a 513 KB Crashpad minidump.

```
$ ls "/home/martin/.config/BraveSoftware/Brave-Browser/Crash Reports/pending/"
(empty)
$ ls "/home/martin/.config/BraveSoftware/Brave-Browser/Crash Reports/new/"
(empty)
```

`~/.config/BraveSoftware/Brave-Browser/Default/LOG` exists but is **0 bytes** (truncated on next browser start at 14:01:29 in the current boot — it has been clobbered, no useful log content survived).

`Local Traces/` directory is empty (was already empty).

## Brave session CPU/memory accounting (post-shutdown systemd accounting)

Captured during shutdown:

```
May 04 13:59:25 skrye systemd[3794]: app-org.chromium.Chromium-25285.scope: Consumed 10min 33.356s CPU time, 65.7M memory peak.
```

(That accounting line is for an older Chromium scope from May 02; it's the tail of accounting being drained. No accounting line was emitted for the live Brave session before the abrupt power-off — graceful shutdown didn't reach Brave's scope before the user pressed power.)

## Current boot health (boot 0)

`journalctl -k -b 0 | grep -iE 'error|warn|fail|amdgpu'` returned no output beyond initial setup — no residual hardware complaints since reboot. `dmesg | grep -iE 'amdgpu|drm|gpu|error|warn'` likewise quiet.

The current boot uses the same kernel (`7.0.2 #1-NixOS`), same command line, same firmware versions reported. No GPU resets, no SMU timeouts, no devcoredump on the current boot.

## Things explicitly NOT found

- No `BUG:`, `Oops`, `general protection fault`, `kernel NULL pointer dereference`, or `kernel panic` in boot -1.
- No OOM killer activity (no `Out of memory` / `Killed process` lines).
- No `kfd` / KFD (compute) errors.
- No NVIDIA / nouveau / i915 involvement (system is AMD-only).
- No `MMU` / `VM_L*` / page fault from the GPU side beyond the UVD register-poll failures during reset.
- No process termination for `brave`, `chrome`, or `chromium` logged in boot -1's journal (the user pressed power before systemd reaped the scope).

## Quick reference: file paths captured

- `/home/martin/Zero/nix-config/nixos/_mixins/desktop/apps/browsers/strix-halo-video-crash.md` — this report
- `/home/martin/.config/BraveSoftware/Brave-Browser/Crash Reports/completed/e7ebee33-cabe-4703-a87e-606750bb5108.dmp` — Brave minidump from 13:58
- `/home/martin/.config/BraveSoftware/Brave-Browser/Crash Reports/completed/e7ebee33-cabe-4703-a87e-606750bb5108.meta` — Brave minidump metadata
- `/var/lib/systemd/coredump/` — no relevant userspace coredumps from boot -1
- `/sys/class/drm/card1/device/devcoredump/` — gone, was the AMDGPU GPU state at reset time
- Boot -1 ID for journalctl queries: `af4e68f3c117457cbdf20b753f1c4b43`

## Kernel patch investigation (2026-05-04)

### Outcome

No defensible kernel patch produced. The Linux kernel was forked to `https://github.com/flexiondotorg/linux`, cloned to `~/Volatile/linux`, branch `fix/strix-halo-vpe-video-decode-hang` exists at `upstream/master` (`6d35786de281`) with no commits. The workaround in this repo (`--disable-accelerated-video-decode --disable-accelerated-video-encode` on `strix-halo`-tagged hosts) remains the active mitigation.

### Hypotheses tested and ruled out

Three candidate patch shapes were evaluated against the actual kernel source:

1. **Ring-activity debounce in the power-gate guard** — would require a settle window between `vpe_ring_end_use` and the `vpe_idle_work_handler` running the SMU PowerDownVpe. The idle work is already scheduled `VPE_IDLE_TIMEOUT` (1000 ms) after the most recent ring use, so any debounce smaller than 1 s is a no-op and any larger is functionally a `VPE_IDLE_TIMEOUT` increase (shape 3 below).

2. **SMU retry/backoff on `PowerDownVpe` ETIMEDOUT** — does not fit. A wedged SMU mailbox does not recover by re-poking; the cascade observed in the boot -1 log (`Failed to power gate VCN`, `Failed to disable gfxoff`, `Failed to retrieve enabled ppfeatures` repeating every ~5 s) confirms the mailbox is fully wedged after the first timeout. SMU send retries are also wider AMD policy territory not appropriate for an outsider patch.

3. **Increase `VPE_IDLE_TIMEOUT` for `IP_VERSION(6, 1, 1)`** — Antheas Kapenekakis's [August 2025 patch](https://lists.freedesktop.org/archives/dri-devel/2025-August/521491.html) took this approach and was superseded by `3ac635367eb5`. Re-submitting the same shape would not constitute new evidence.

### IP_VERSION confirmation (refutes earlier hypothesis)

Investigation suggested an "extend the switch in `vpe_need_dpm0_at_power_down()` to add `IP_VERSION(6, 1, 0)`" one-line patch was possible, motivated by the boot-log line `detected ip block number 11 <vpe_v6_1_0> (vpe_v6_1)`. **Refuted** by reading the kernel source plus on-die discovery sysfs:

- `/sys/class/drm/card1/device/ip_discovery/die/0/VPE/0/{major,minor,revision}` reports `6, 1, 1` on `skrye`.
- The boot-log string `<vpe_v6_1_0>` is the hard-coded `.rev = 0` field of the static `vpe_v6_1_ip_block` (`drivers/gpu/drm/amd/amdgpu/amdgpu_vpe.c`); it is constant across all VPE 6.1.x parts and is unrelated to the runtime `IP_VERSION` value used in the dispatch switch.
- `vpe_early_init()` only enables `collaborate_mode` for `IP_VERSION(6, 1, 1)`; skrye's boot log shows `VPE: collaborate mode true`, consistent with the sysfs reading.

The existing guard `vpe_need_dpm0_at_power_down()` (added by `3ac635367eb5`) does cover Strix Halo's IP_VERSION. The PMFW threshold `< 0x0a640500` is the active determinant: skrye on BIOS 03.05 is above that threshold, so the guard returns `false` and the upstream workaround does not run.

### What's needed before a patch is defensible

Three items, in order of leverage:

1. A fresh **AMDGPU devcoredump** captured from `/sys/class/drm/card1/device/devcoredump/data` immediately after the next reproduction (within the 5-minute auto-expiry). A udev rule or systemd path unit is the right scaffolding.
2. **SMU mailbox tracing** (`echo 'file *smu* +p' > /sys/kernel/debug/dynamic_debug/control` plus `dyndbg='file *smu* +p'` boot param) to capture the message immediately preceding `PowerDownVpe` and the inter-message timing.
3. Engagement with **Mario Limonciello** (commit `3ac635367eb5` author) on LP #2148686 with skrye's crash log, asking whether the PMFW `0x0a640500` threshold is correct for sustained VA-API video-decode workloads or whether the gate needs lifting / removing on (6, 1, 1).

### Source paths inspected

```
/home/martin/Volatile/linux/drivers/gpu/drm/amd/amdgpu/amdgpu_vpe.c   (lines 304-333, 1012-1018)
/home/martin/Volatile/linux/drivers/gpu/drm/amd/amdgpu/amdgpu_discovery.c   (lines 2732-2745)
/home/martin/Volatile/linux/drivers/gpu/drm/amd/amdgpu/amdgpu_ip.c   (lines 241-245)
/home/martin/Volatile/linux/drivers/gpu/drm/amd/amdgpu/vpe_v6_1.c   (lines 35-37, 135-145)
/home/martin/Volatile/linux/drivers/gpu/drm/amd/pm/swsmu/smu14/smu_v14_0_0_ppt.c (smu_v14_0_0_set_vpe_enable, ~line 1557)
```
