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
        legacy = mod.parse_args(["flint", "5"])
        self.assertEqual(legacy.models, ["flint"])
        self.assertEqual(legacy.runs, 5)
        self.assertFalse(legacy.emit_json)

        suite = mod.parse_args(["--llama-only", "--json", "--runs", "2", "flint", "inkling-2-mini"])
        self.assertEqual(suite.models, ["flint", "inkling-2-mini"])
        self.assertEqual(suite.runs, 2)
        self.assertTrue(suite.llama_only)
        self.assertTrue(suite.emit_json)

    def test_cache_prefers_preseed_and_falls_back_to_download(self):
        mod = load_focused()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "volatile"
            preseed = Path(tmp) / "preseed"
            preseed_file = (
                preseed / "hub" / "models--unsloth--flint-GGUF" / "snapshots" / "abc123" / "flint-Q8_0.gguf"
            )
            preseed_file.parent.mkdir(parents=True, exist_ok=True)
            preseed_file.write_bytes(b"gguf")

            vol_file = (
                root / "huggingface" / "hub" / "models--unsloth--flint-GGUF" / "snapshots" / "def456" / "flint-Q8_0.gguf"
            )
            vol_file.parent.mkdir(parents=True, exist_ok=True)
            vol_file.write_bytes(b"gguf")

            profile = {
                "snapshot": "hub/models--unsloth--flint-GGUF/snapshots/*/flint-Q8_0.gguf",
                "hfRepo": "unsloth/flint-GGUF",
                "downloadPaths": ["flint-Q8_0.gguf"],
                "projectorPath": None,
                "revision": None,
            }
            with mock.patch.dict(os.environ, {"BENCHMARK_MODELS_PRESEED_CACHE": str(preseed)}):
                resolved = mod.ensure_model_path("flint", profile, root)
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
                    resolved_after = mod.ensure_model_path("flint", profile, root)
                    self.assertEqual(resolved_after, vol_file.resolve())
                    run_mock.assert_called_once()
                    self.assertIn("unsloth/flint-GGUF", run_mock.call_args.args[0])

    def test_classify_ollama_error_marks_unknown_arch_unsupported(self):
        mod = load_focused()
        status, reason = mod.classify_ollama_error("Error: unknown model architecture: 'flint'")
        self.assertEqual(status, "unsupported")
        self.assertIn("flint", reason)

        status2, _ = mod.classify_ollama_error("connection reset by peer")
        self.assertEqual(status2, "failed")

    def test_format_summary_table_and_deltas(self):
        mod = load_focused()
        results = [
            {
                "model": "gemma4-e4b",
                "runner": "llama.cpp",
                "backend": "vulkan",
                "mode": "off",
                "status": "ok",
                "medians": {"prefill_tps": 1200.0, "decode_tps": 100.0, "ttft_ms": 3400.0, "total_ms": 8500.0},
                "device_peak_bytes": {"card1/mem_info_vram_used": 10 * 1024 ** 3},
            },
            {
                "model": "gemma4-e4b",
                "runner": "ollama",
                "backend": "vulkan",
                "mode": "off",
                "status": "ok",
                "medians": {"prefill_tps": 1000.0, "decode_tps": 80.0, "ttft_ms": 4100.0, "total_ms": 10500.0},
                "device_peak_bytes": {"card1/mem_info_vram_used": 11 * 1024 ** 3},
            },
            {
                "model": "flint",
                "runner": "ollama",
                "backend": "vulkan",
                "mode": "off",
                "status": "unsupported",
                "error": "unknown model architecture: 'flint'",
            },
        ]
        table = mod.format_summary_table(results, runs=3)
        self.assertIn("Prefill tok/s", table)
        self.assertIn("Decode tok/s", table)
        self.assertIn("10.0 GiB", table)
        self.assertIn("unsupported: unknown model architecture: 'flint'", table)
        self.assertIn("gemma4-e4b (vulkan): llama.cpp vs ollama decode +25.0%, prefill +20.0%", table)


if __name__ == "__main__":
    unittest.main()
