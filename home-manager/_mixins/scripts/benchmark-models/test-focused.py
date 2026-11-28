# The benchmark-models build runs these unit tests through default.nix postCheck.
import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT_PATH = Path(sys.argv[1])
sys.argv[1:] = []


def load_focused():
    spec = importlib.util.spec_from_file_location("focused_under_test", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FocusedBenchmarkTests(unittest.TestCase):
    def test_parse_args_legacy_and_suite(self):
        mod = load_focused()
        legacy = mod.parse_args(["qwen3.8-27b", "5"])
        self.assertEqual(legacy.models, ["qwen3.8-27b"])
        self.assertEqual(legacy.runs, 5)
        self.assertFalse(legacy.emit_json)

        suite = mod.parse_args(["--llama-only", "--json", "--runs", "2", "qwen3.8-27b", "inkling-2-mini"])
        self.assertEqual(suite.models, ["qwen3.8-27b", "inkling-2-mini"])
        self.assertEqual(suite.runs, 2)
        self.assertTrue(suite.llama_only)
        self.assertTrue(suite.emit_json)

    def test_cache_prefers_preseed_and_falls_back_to_download(self):
        mod = load_focused()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "volatile"
            preseed = Path(tmp) / "preseed"
            preseed_file = (
                preseed / "hub" / "models--unsloth--Qwen3.8-27B-GGUF" / "snapshots" / "abc123" / "Qwen3.8-27B-UD-Q4_K_XL.gguf"
            )
            preseed_file.parent.mkdir(parents=True, exist_ok=True)
            preseed_file.write_bytes(b"gguf")

            vol_file = (
                root / "huggingface" / "hub" / "models--unsloth--Qwen3.8-27B-GGUF" / "snapshots" / "def456" / "Qwen3.8-27B-UD-Q4_K_XL.gguf"
            )
            vol_file.parent.mkdir(parents=True, exist_ok=True)
            vol_file.write_bytes(b"gguf")

            profile = {
                "snapshot": "hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/*/Qwen3.8-27B-UD-Q4_K_XL.gguf",
                "hfRepo": "unsloth/Qwen3.8-27B-GGUF",
                "downloadPaths": ["Qwen3.8-27B-UD-Q4_K_XL.gguf"],
                "projectorPath": None,
                "revision": None,
            }
            with mock.patch.dict(os.environ, {"BENCHMARK_MODELS_PRESEED_CACHE": str(preseed)}):
                resolved = mod.ensure_model_path("qwen3.8-27b", profile, root)
                self.assertEqual(resolved, preseed_file.resolve())

                # Remove preseed and volatile copies to verify hf download fallback.
                preseed_file.unlink()
                vol_file.unlink()

                def fake_download(cmd, env=None, check=False):
                    vol_file.write_bytes(b"downloaded")
                    return mock.Mock(returncode=0)

                with (
                    mock.patch.object(mod.shutil, "which", return_value="/bin/hf"),
                    mock.patch.object(mod.subprocess, "run", side_effect=fake_download) as run_mock,
                ):
                    resolved_after = mod.ensure_model_path("qwen3.8-27b", profile, root)
                    self.assertEqual(resolved_after, vol_file.resolve())
                    run_mock.assert_called_once()
                    self.assertIn("unsloth/Qwen3.8-27B-GGUF", run_mock.call_args.args[0])

    def test_classify_ollama_error_marks_unknown_arch_unsupported(self):
        mod = load_focused()
        status, reason = mod.classify_ollama_error("Error: unknown model architecture: 'inkling2_loop'")
        self.assertEqual(status, "unsupported")
        self.assertEqual(reason, "unknown model architecture: 'inkling2_loop'")

        status2, reason2 = mod.classify_ollama_error("connection reset by peer")
        self.assertEqual(status2, "failed")
        self.assertEqual(reason2, "connection reset by peer")

    def test_classify_ollama_error_unwraps_http_500_json_and_server_log(self):
        mod = load_focused()
        raw_http_500 = (
            "/api/generate: HTTP 500: b'{\"error\":\"llama-server process has terminated: "
            "exit status 1: error loading model: unknown model architecture: "
            "\\'inkling2_loop\\'\\nerror loading model: unknown model architecture: "
            "\\'inkling2_loop\\'\"}'"
        )
        status, reason = mod.classify_ollama_error(raw_http_500)
        self.assertEqual(status, "unsupported")
        self.assertEqual(reason, "unknown model architecture: 'inkling2_loop'")

        formatted = mod.format_http_error(
            "/api/generate",
            500,
            b'{"error":"llama-server process has terminated: exit status 1: '
            b'error loading model: unknown model architecture: \'inkling2_loop\'"}',
        )
        status_fmt, reason_fmt = mod.classify_ollama_error(formatted)
        self.assertEqual(status_fmt, "unsupported")
        self.assertEqual(reason_fmt, "unknown model architecture: 'inkling2_loop'")

        server_log = "\n".join(
            [
                "llama_model_load: error loading model: unknown model architecture: 'inkling2_loop'",
                "llama_model_load_from_file_impl: failed to load model",
                'time=2026-11-26T16:44:12.397Z level=ERROR source=llama_server.go:1073 msg="llama-server terminated" error="exit status 1"',
            ]
        )
        status_log, reason_log = mod.classify_ollama_error(
            "/api/generate: HTTP 500: llama-server process has terminated: exit status 1",
            server_log=server_log,
        )
        self.assertEqual(status_log, "unsupported")
        self.assertEqual(reason_log, "unknown model architecture: 'inkling2_loop'")

        truncated_json = (
            '/api/generate: HTTP 500: {"error":"llama-server process has terminated: '
            "exit status 1: error loading model: unknown model architecture: 'inkling2_loop'"
        )
        status_trunc, reason_trunc = mod.classify_ollama_error(truncated_json)
        self.assertEqual(status_trunc, "unsupported")
        self.assertEqual(reason_trunc, "unknown model architecture: 'inkling2_loop'")

    def test_ollama_env_enables_igpu_for_vulkan_only(self):
        mod = load_focused()
        base_env = {"PATH": "/usr/bin"}
        vulkan_env = mod.build_ollama_env("vulkan", 11435, Path("/tmp/h"), Path("/tmp/m"), base_env=base_env)
        self.assertEqual(vulkan_env["OLLAMA_IGPU_ENABLE"], "1")
        self.assertEqual(vulkan_env["OLLAMA_VULKAN"], "1")
        self.assertEqual(vulkan_env["OLLAMA_NUM_PARALLEL"], "1")
        self.assertEqual(vulkan_env["OLLAMA_FLASH_ATTENTION"], "1")
        self.assertEqual(vulkan_env["OLLAMA_KV_CACHE_TYPE"], "q8_0")

        rocm_env = mod.build_ollama_env("rocm", 11435, Path("/tmp/h"), Path("/tmp/m"), base_env=base_env)
        self.assertNotIn("OLLAMA_IGPU_ENABLE", rocm_env)
        self.assertNotIn("OLLAMA_VULKAN", rocm_env)

        cuda_env = mod.build_ollama_env("cuda", 11435, Path("/tmp/h"), Path("/tmp/m"), base_env=base_env)
        self.assertNotIn("OLLAMA_IGPU_ENABLE", cuda_env)

    def test_ollama_payload_and_cache_busting_prompts(self):
        mod = load_focused()
        prompts = [
            mod.build_benchmark_prompt_text(190, nonce=mod.make_ollama_nonce("deadbeef", step))
            for step in range(4)
        ]
        self.assertEqual(len(set(prompts)), 4)
        first_lines = [p.splitlines()[0] for p in prompts]
        self.assertEqual(first_lines, ["00-deadbeef", "01-deadbeef", "02-deadbeef", "03-deadbeef"])
        for prompt in prompts:
            self.assertIn("Application log:\n", prompt)
            self.assertIn("summarise_log(lines)", prompt)

        payload_default = mod.build_ollama_payload(
            "benchmark-qwen",
            prompts[0],
            {"sampling": {"temperature": 1.0, "top_p": 0.95}, "reasoning": "on"},
        )
        self.assertEqual(payload_default["options"]["num_ctx"], 8192)
        self.assertEqual(payload_default["options"]["num_batch"], 512)
        self.assertEqual(payload_default["options"]["num_predict"], mod.OUTPUT_TOKENS)
        self.assertEqual(payload_default["options"]["seed"], mod.SEED)
        self.assertTrue(payload_default["think"])

        payload_micro = mod.build_ollama_payload(
            "benchmark-inkling",
            prompts[1],
            {"microBatchSize": 128, "sampling": {}, "reasoning": "off"},
            num_predict=1,
        )
        self.assertEqual(payload_micro["options"]["num_batch"], 128)
        self.assertEqual(payload_micro["options"]["num_predict"], 1)
        self.assertFalse(payload_micro["think"])

        payload_default_reasoning = mod.build_ollama_payload(
            "benchmark-mellum",
            prompts[2],
            {"microBatchSize": None, "sampling": {"temperature": 0.6, "top_p": 0.95, "top_k": 20}, "reasoning": None},
        )
        self.assertEqual(payload_default_reasoning["options"]["num_batch"], 512)
        self.assertNotIn("think", payload_default_reasoning)

    def test_ollama_prompt_calibration_targets_prompt_tokens(self):
        mod = load_focused()
        # Simulate Qwen3.8 (~21 tokens/line, 60 base tokens).
        estimated = mod.estimate_prompt_lines(4096, base_tokens=60, probe_lines=150, probe_tokens=60 + 150 * 21)
        self.assertEqual(estimated, 192)

        seen_prompts: list[str] = []

        def fake_generate(port, tag, prompt_text, profile, num_predict=mod.OUTPUT_TOKENS, require_eval=True):
            seen_prompts.append(prompt_text)
            self.assertEqual(num_predict, 1)
            self.assertFalse(require_eval)
            log_lines = sum(1 for ln in prompt_text.splitlines() if " worker=" in ln)
            prompt_n = 60 + log_lines * 21
            return {
                "ttft_ms": 10.0,
                "total_ms": 10.0,
                "prefill_tps": 1000.0,
                "decode_tps": 0.0,
                "timings": {"prompt_n": prompt_n, "predicted_n": 1},
            }

        step_counter = [0]
        with mock.patch.object(mod, "ollama_generate", side_effect=fake_generate):
            target_lines, base_tokens = mod.calibrate_ollama_prompt_lines(
                11435,
                "benchmark-qwen",
                {"sampling": {}},
                "cafebabe",
                step_counter,
            )
        self.assertEqual(base_tokens, 60)
        self.assertEqual(target_lines, 192)
        self.assertEqual(step_counter[0], 2)
        self.assertEqual(len(set(p.splitlines()[0] for p in seen_prompts)), 2)

    def test_peak_vram_bytes_sums_vram_and_gtt_per_card(self):
        mod = load_focused()
        # Strix Halo unified memory: 0.5 GiB VRAM carveout + ~46.8 GiB GTT.
        apu_peaks = {
            "card1/mem_info_preempt_used": 440_565_760,
            "card1/mem_info_vram_used": 528_506_880,
            "card1/mem_info_vis_vram_used": 528_506_880,
            "card1/mem_info_gtt_used": 50_224_361_472,
        }
        self.assertEqual(mod.peak_vram_bytes(apu_peaks), 528_506_880 + 50_224_361_472)

        # Discrete GPU with VRAM only.
        dgpu_peaks = {"card1/mem_info_vram_used": 10 * 1024 ** 3}
        self.assertEqual(mod.peak_vram_bytes(dgpu_peaks), 10 * 1024 ** 3)

        # Multi-card picks the highest per-card (vram + gtt) total.
        multi_peaks = {
            "card0/mem_info_vram_used": 2 * 1024 ** 3,
            "card0/mem_info_gtt_used": 1 * 1024 ** 3,
            "card1/mem_info_vram_used": 1 * 1024 ** 3,
            "card1/mem_info_gtt_used": 20 * 1024 ** 3,
        }
        self.assertEqual(mod.peak_vram_bytes(multi_peaks), 21 * 1024 ** 3)
        self.assertIsNone(mod.peak_vram_bytes(None))

    def test_delta_gpu_bytes_calculates_clamps_and_handles_missing(self):
        mod = load_focused()
        gib = 1024 ** 3
        self.assertEqual(mod.delta_gpu_bytes(50 * gib, 6 * gib), 44 * gib)
        self.assertEqual(mod.delta_gpu_bytes(4 * gib, 6 * gib), 0)
        self.assertIsNone(mod.delta_gpu_bytes(None, 6 * gib))
        self.assertIsNone(mod.delta_gpu_bytes(50 * gib, None))
        self.assertIsNone(mod.delta_gpu_bytes(None, None))

    def test_nvidia_gpu_memory_parses_selects_max_and_handles_errors(self):
        mod = load_focused()
        mib = 1024 * 1024

        completed = mock.Mock(returncode=0, stdout="0, 1024\n1, 11456\n")
        with (
            mock.patch.object(mod.shutil, "which", return_value="/run/current-system/sw/bin/nvidia-smi"),
            mock.patch.object(mod.subprocess, "run", return_value=completed) as run_mock,
        ):
            reading = mod.nvidia_gpu_memory()
        self.assertEqual(reading, {"nvidia0/vram_used": 1024 * mib, "nvidia1/vram_used": 11456 * mib})
        self.assertEqual(mod.peak_vram_bytes(reading), 11456 * mib)
        self.assertEqual(mod.delta_gpu_bytes(mod.peak_vram_bytes(reading), 512 * mib), (11456 - 512) * mib)
        run_mock.assert_called_once()

        # Invalid, negative, malformed, and empty lines are ignored while valid lines survive.
        mixed = mock.Mock(returncode=0, stdout="\n0, [N/A]\nbad, 500\n1, -10\n2, 2048\nonlyone\n")
        with mock.patch.object(mod.subprocess, "run", return_value=mixed):
            self.assertEqual(mod.nvidia_gpu_memory("/bin/nvidia-smi"), {"nvidia2/vram_used": 2048 * mib})

        # Empty output, non-zero exit code, subprocess timeout, OSError, or missing binary return {}.
        with mock.patch.object(mod.subprocess, "run", return_value=mock.Mock(returncode=0, stdout="")):
            self.assertEqual(mod.nvidia_gpu_memory("/bin/nvidia-smi"), {})
        with mock.patch.object(mod.subprocess, "run", return_value=mock.Mock(returncode=1, stdout="0, 1024\n")):
            self.assertEqual(mod.nvidia_gpu_memory("/bin/nvidia-smi"), {})
        with mock.patch.object(mod.subprocess, "run", side_effect=mod.subprocess.TimeoutExpired("nvidia-smi", 2)):
            self.assertEqual(mod.nvidia_gpu_memory("/bin/nvidia-smi"), {})
        with mock.patch.object(mod.subprocess, "run", side_effect=OSError("not found")):
            self.assertEqual(mod.nvidia_gpu_memory("/bin/nvidia-smi"), {})
        with mock.patch.object(mod.shutil, "which", return_value=None):
            self.assertEqual(mod.nvidia_gpu_memory(), {})

    def test_snapshot_and_sample_gpu_memory_fall_back_to_nvidia(self):
        mod = load_focused()
        mib = 1024 * 1024

        with (
            mock.patch.object(mod, "amdgpu_memory_counters", return_value=[]),
            mock.patch.object(mod, "nvidia_gpu_memory", return_value={"nvidia0/vram_used": 4096 * mib}) as nv_mock,
        ):
            snap = mod.snapshot_gpu_memory()
            self.assertEqual(snap, {"nvidia0/vram_used": 4096 * mib})
            self.assertEqual(mod.snapshot_gpu_memory([]), {})
            nv_mock.assert_called_once()

        # When neither amdgpu counters nor nvidia-smi exist, sample_gpu_memory returns immediately.
        stop = mod.Event()
        peaks: dict[str, int] = {}
        with (
            mock.patch.object(mod, "amdgpu_memory_counters", return_value=[]),
            mock.patch.object(mod.shutil, "which", return_value=None),
        ):
            mod.sample_gpu_memory(stop, peaks)
        self.assertEqual(peaks, {})

        # When amdgpu counters are absent and nvidia-smi is present, sample_gpu_memory tracks the peak.
        stop2 = mod.Event()
        peaks2: dict[str, int] = {}
        samples = iter([{"nvidia0/vram_used": 2048 * mib}, {"nvidia0/vram_used": 8192 * mib}])

        def fake_nvidia(binary=None):
            try:
                reading = next(samples)
            except StopIteration:
                stop2.set()
                return {}
            if reading["nvidia0/vram_used"] == 8192 * mib:
                stop2.set()
            return reading

        with (
            mock.patch.object(mod, "amdgpu_memory_counters", return_value=[]),
            mock.patch.object(mod.shutil, "which", return_value="/bin/nvidia-smi"),
            mock.patch.object(mod, "nvidia_gpu_memory", side_effect=fake_nvidia),
        ):
            mod.sample_gpu_memory(stop2, peaks2)
        self.assertEqual(peaks2, {"nvidia0/vram_used": 8192 * mib})
        self.assertEqual(mod.peak_vram_bytes(peaks2), 8192 * mib)

    def test_llama_case_matrix_sweeps_mtp_for_supported_backends_and_models(self):
        mod = load_focused()
        for draft_tokens in (2, 3):
            self.assertEqual(mod.mtp_widths_for_backend("vulkan", draft_tokens), (0, 2, 3, 4))
            self.assertEqual(mod.mtp_widths_for_backend("cuda", draft_tokens), (0, 2, 3, 4, 5, 6))
            self.assertEqual(mod.mtp_widths_for_backend("rocm", draft_tokens), (0, 2, 3))
            cases = mod.llama_case_matrix(["vulkan", "rocm"], draft_tokens)
            vulkan_widths = [w for b, w in cases if b == "vulkan"]
            rocm_widths = [w for b, w in cases if b == "rocm"]
            self.assertEqual(vulkan_widths, [0, 2, 3, 4])
            self.assertEqual(rocm_widths, [0, 2, 3])

        cuda_cases = mod.llama_case_matrix(["vulkan", "cuda"], 3)
        self.assertEqual([w for b, w in cuda_cases if b == "vulkan"], [0, 2, 3, 4])
        self.assertEqual([w for b, w in cuda_cases if b == "cuda"], [0, 2, 3, 4, 5, 6])

        # Models with MTP tensors sweep MTP even when production leaves mtpDraftTokens unset.
        utility_cases = mod.llama_case_matrix(["vulkan", "cuda"], None, supports_mtp=True)
        self.assertEqual([w for b, w in utility_cases if b == "vulkan"], [0, 2, 3, 4])
        self.assertEqual([w for b, w in utility_cases if b == "cuda"], [0, 2, 3, 4, 5, 6])

        non_mtp = mod.llama_case_matrix(["vulkan", "rocm"], None)
        self.assertEqual(non_mtp, [("vulkan", 0), ("rocm", 0)])

    def test_format_summary_table_and_deltas(self):
        mod = load_focused()
        gib = 1024 ** 3
        results = [
            {
                "model": "qwen3.5-9b",
                "runner": "llama.cpp",
                "backend": "vulkan",
                "mode": "off",
                "status": "ok",
                "medians": {"prefill_tps": 1200.0, "decode_tps": 100.0, "ttft_ms": 3400.0, "total_ms": 8500.0},
                "device_peak_bytes": {
                    "card1/mem_info_vram_used": 1 * gib,
                    "card1/mem_info_vis_vram_used": 1 * gib,
                    "card1/mem_info_gtt_used": 9 * gib,
                },
                "baseline_gpu_bytes": 2 * gib,
            },
            {
                "model": "qwen3.5-9b",
                "runner": "ollama",
                "backend": "vulkan",
                "mode": "off",
                "status": "ok",
                "medians": {"prefill_tps": 1000.0, "decode_tps": 80.0, "ttft_ms": 4100.0, "total_ms": 10500.0},
                "device_peak_bytes": {"card1/mem_info_vram_used": 11 * gib},
                "baseline_gpu_bytes": 12 * gib,
                "peak_gpu_bytes": 11 * gib,
                "delta_gpu_bytes": 0,
            },
            {
                "model": "qwen3.8-27b",
                "runner": "llama.cpp",
                "backend": "vulkan",
                "mode": "mtp3",
                "status": "ok",
                "medians": {"prefill_tps": 500.0, "decode_tps": 28.0, "ttft_ms": 8100.0, "total_ms": 26000.0},
                "peak_gpu_bytes": 24 * gib,
                "baseline_gpu_bytes": None,
                "delta_gpu_bytes": None,
            },
            {
                "model": "inkling-2-mini",
                "runner": "ollama",
                "backend": "vulkan",
                "mode": "off",
                "status": "unsupported",
                "error": "unknown model architecture: 'inkling2_loop'",
            },
        ]
        table = mod.format_summary_table(results, runs=3)
        self.assertIn("Prefill tok/s", table)
        self.assertIn("Decode tok/s", table)
        self.assertIn("Peak GPU Mem  Delta GPU Mem", table)
        self.assertIn("10.0 GiB        8.0 GiB", table)
        self.assertIn("11.0 GiB        0.0 GiB", table)
        self.assertIn("24.0 GiB              -", table)
        self.assertIn("unsupported: unknown model architecture: 'inkling2_loop'", table)
        self.assertIn("qwen3.5-9b (vulkan): llama.cpp vs ollama decode +25.0%, prefill +20.0%", table)


if __name__ == "__main__":
    unittest.main()
