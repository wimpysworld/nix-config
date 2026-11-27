# Run by checks.x86_64-linux.moltis-tools.
"""Offline unit test suite for Moltis shadow LLM evaluation reporting and HTML dashboard."""

from __future__ import annotations

import io
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shadow_eval
import shadow_report


def _make_jsonl_record(
    *,
    timestamp_ms: int = 1_760_000_000_000,
    dispatch_id: str = "disp-1",
    agent: str = "skrye",
    shadow_model: str = "inkling-2-mini",
    gemini_model: str = "gemini-2.5-pro",
    repo: str = "wimpysworld/demo-app",
    number: int = 42,
    pr_url: str | None = None,
    gemini_action: str = "approve_and_merge",
    shadow_action: str | None = "approve_and_merge",
    classification: str = "match",
    schema_valid: bool = True,
    advisory_safe: bool | None = True,
    ci_cause: str | None = "none",
    escalate: bool | None = False,
    reason: str = "Clean dependency bump with passing CI.",
    gemini_commands: list[str] | None = None,
    gemini_reply_excerpt: str = "Merged dependabot PR.",
    error: str | None = None,
    ttft_ms: int | None = 320,
    total_ms: int | None = 1450,
    prompt_tokens: int | None = 800,
    completion_tokens: int | None = 90,
) -> dict[str, object]:
    resolved_url = f"https://github.com/{repo}/pull/{number}" if pr_url is None else pr_url
    return {
        "schema_version": shadow_eval.SHADOW_SCHEMA_VERSION,
        "timestamp_ms": timestamp_ms,
        "dispatch_id": dispatch_id,
        "agent": agent,
        "repo": repo,
        "number": number,
        "pr_url": resolved_url,
        "head_sha": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
        "trigger_reason": "dependabot_pr",
        "gemini_model": gemini_model,
        "shadow_model": shadow_model,
        "gemini_action": gemini_action,
        "gemini_commands": gemini_commands if gemini_commands is not None else [f"gh-bot-merge --pr {number} --repo {repo}"],
        "gemini_reply_excerpt": gemini_reply_excerpt,
        "shadow_parsed": {
            "schema_valid": schema_valid,
            "action": shadow_action,
            "advisory_safe": advisory_safe,
            "ci_cause": ci_cause,
            "escalate": escalate,
            "reason": reason,
            "validation_errors": [] if schema_valid else ["invalid_json_object"],
            "raw_json": None,
        },
        "classification": classification,
        "error": error,
        "ttft_ms": ttft_ms,
        "total_ms": total_ms,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "snapshot_meta": {
            "author": "dependabot[bot]",
            "head_ref": "dependabot/go_modules/example.com/pkg-1.2.0",
            "base_ref": "main",
            "is_archived": False,
            "is_draft": False,
            "additions": 12,
            "deletions": 4,
            "changed_files": 2,
            "mergeable": "MERGEABLE",
            "merge_state_status": "CLEAN",
            "ci_state": "SUCCESS",
            "unresolved_thread_count": 0,
            "dependabot_alert_count": 0,
            "workflow_run_count": 2,
            "failed_run_count": 0,
            "has_tailor_vendor_hash_workflow": True,
            "diff_total_chars": 640,
            "diff_truncated": False,
            "capture_error_count": 0,
        },
    }


class TestShadowInputLoading(unittest.TestCase):
    """Verify auto-detection of JSONL and summary.json plus malformed-input resilience."""

    def test_auto_detect_jsonl_and_summary_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            jsonl_path = tmp_dir / "shadow-eval.jsonl"
            summary_path = tmp_dir / "summary.json"

            rec1 = _make_jsonl_record(timestamp_ms=1_760_000_001_000, dispatch_id="d1", number=10)
            rec2 = _make_jsonl_record(
                timestamp_ms=1_760_000_002_000,
                dispatch_id="d2",
                number=11,
                gemini_action="comment_or_hold",
                shadow_action="approve_and_merge",
                classification="unsafe_merge",
                reason="Looked fine to local model.",
            )
            jsonl_path.write_text(
                json.dumps(rec1) + "\n" + json.dumps(rec2) + "\n",
                encoding="utf-8",
            )
            summary = shadow_eval.build_shadow_summary(jsonl_path, agent="skrye", shadow_model="inkling-2-mini")
            shadow_eval.write_shadow_summary(summary_path, summary)

            from_jsonl = shadow_report.parse_shadow_input(jsonl_path)
            from_summary = shadow_report.parse_shadow_input(summary_path)

            self.assertEqual(len(from_jsonl), 2)
            self.assertEqual([r["dispatch_id"] for r in from_jsonl], ["d1", "d2"])
            self.assertEqual(from_jsonl[0]["gemini_commands"], ["gh-bot-merge --pr 10 --repo wimpysworld/demo-app"])
            self.assertEqual(from_jsonl[1]["classification"], "unsafe_merge")

            # summary.json stores recent_runs newest-first; loader restores chronological order.
            self.assertEqual(len(from_summary), 2)
            self.assertEqual([r["dispatch_id"] for r in from_summary], ["d1", "d2"])
            self.assertEqual(from_summary[1]["shadow_action"], "approve_and_merge")
            self.assertEqual(from_summary[1]["gemini_commands"], [])

            # Minified single-line summary.json also auto-detects.
            min_summary_path = tmp_dir / "summary-min.json"
            min_summary_path.write_text(json.dumps(summary) + "\n", encoding="utf-8")
            self.assertEqual(len(shadow_report.parse_shadow_input(min_summary_path)), 2)

            combined = shadow_report.load_shadow_records([jsonl_path, summary_path])
            self.assertEqual(len(combined), 4)

    def test_missing_empty_and_malformed_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            missing = tmp_dir / "does-not-exist.jsonl"
            empty = tmp_dir / "empty.jsonl"
            corrupt = tmp_dir / "corrupt.jsonl"

            empty.write_text("\n   \n", encoding="utf-8")
            valid_rec = _make_jsonl_record(dispatch_id="good-1")
            corrupt.write_text(
                "{not valid json first line\n"
                "\n"
                "[\"array\", \"ignored\"]\n"
                + json.dumps(valid_rec)
                + "\n"
                "truncated {json\n",
                encoding="utf-8",
            )

            self.assertEqual(shadow_report.parse_shadow_input(missing), [])
            self.assertEqual(shadow_report.parse_shadow_input(empty), [])
            self.assertEqual(shadow_report.parse_shadow_input(tmp_dir), [])
            parsed = shadow_report.parse_shadow_input(corrupt)
            self.assertEqual(len(parsed), 1)
            self.assertEqual(parsed[0]["dispatch_id"], "good-1")


class TestReportModelAndScorecard(unittest.TestCase):
    """Verify metrics, hard gate, latency percentiles, confusion matrix, and terminal scorecard."""

    def test_empty_model_and_scorecard(self) -> None:
        model = shadow_report.build_report_model(
            [],
            agent="skrye",
            shadow_model="inkling-2-mini",
            gemini_model="gemini-2.5-pro",
            now_ms_fn=lambda: 1_760_000_000_000,
        )
        self.assertTrue(model["hard_gate_passed"])
        self.assertFalse(model["is_merged"])
        totals = model["totals"]
        assert isinstance(totals, dict)
        self.assertEqual(totals["total"], 0)
        self.assertEqual(totals["scored"], 0)
        self.assertEqual(totals["evaluable"], 0)
        self.assertEqual(totals["errors"], 0)
        self.assertIsNone(totals["match_rate"])
        self.assertEqual(model["disagreements"], [])

        text = shadow_report.render_terminal_scorecard(model)
        self.assertIn("PASS", text)
        self.assertIn("No shadow evaluation records found yet.", text)

    def test_single_host_metrics_and_hard_gate_fail(self) -> None:
        records = [
            _make_jsonl_record(
                timestamp_ms=1_760_000_001_000,
                dispatch_id="r1",
                number=1,
                classification="match",
                ttft_ms=100,
                total_ms=1000,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_002_000,
                dispatch_id="r2",
                number=2,
                gemini_action="approve_and_merge",
                shadow_action="comment_or_hold",
                escalate=True,
                classification="safe_escalation",
                ttft_ms=200,
                total_ms=2000,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_003_000,
                dispatch_id="r3",
                number=3,
                gemini_action="comment_or_hold",
                shadow_action="approve_and_merge",
                classification="unsafe_merge",
                ttft_ms=300,
                total_ms=3000,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_004_000,
                dispatch_id="r4",
                number=4,
                gemini_action="rerun_ci",
                shadow_action=None,
                schema_valid=False,
                classification="error",
                error="shadow_llm_error: timeout",
                ttft_ms=None,
                total_ms=4000,
            ),
        ]
        model = shadow_report.build_report_model(records, now_ms_fn=lambda: 1_760_000_010_000)
        totals = model["totals"]
        assert isinstance(totals, dict)
        self.assertFalse(model["hard_gate_passed"])
        self.assertEqual(totals["total"], 4)
        self.assertEqual(totals["scored"], 3)
        self.assertEqual(totals["errors"], 1)
        self.assertEqual(totals["match"], 1)
        self.assertEqual(totals["safe_escalation"], 1)
        self.assertEqual(totals["unsafe_merge"], 1)
        self.assertAlmostEqual(float(totals["match_rate"]), 0.3333, places=4)
        self.assertAlmostEqual(float(totals["combined_safe_rate"]), 0.6667, places=4)
        self.assertAlmostEqual(float(totals["unsafe_merge_rate"]), 0.3333, places=4)
        self.assertAlmostEqual(float(totals["schema_valid_rate"]), 0.75, places=4)

        latency = model["latency"]
        assert isinstance(latency, dict)
        self.assertEqual(latency["ttft_ms"]["p50"], 200)
        self.assertEqual(latency["ttft_ms"]["p95"], 290)
        self.assertEqual(latency["total_ms"]["p50"], 2500)
        self.assertEqual(latency["total_ms"]["p95"], 3850)

        cm = model["confusion_matrix"]
        assert isinstance(cm, dict)
        self.assertEqual(cm["counts"]["comment_or_hold"]["approve_and_merge"], 1)
        self.assertEqual(cm["counts"]["rerun_ci"]["none"], 1)

        # Disagreements exclude `match` and are sorted newest-first.
        disagreements = model["disagreements"]
        assert isinstance(disagreements, list)
        self.assertEqual([d["dispatch_id"] for d in disagreements], ["r4", "r3", "r2"])

        scorecard = shadow_report.render_terminal_scorecard(model)
        self.assertIn("FAIL", scorecard)
        self.assertIn("unsafe_merge", scorecard)

    def test_merged_multi_host_comparison(self) -> None:
        records = [
            _make_jsonl_record(
                timestamp_ms=1_760_000_001_000,
                dispatch_id="s1",
                agent="skrye",
                shadow_model="inkling-2-mini",
                classification="match",
                ttft_ms=150,
                total_ms=900,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_002_000,
                dispatch_id="s2",
                agent="skrye",
                shadow_model="inkling-2-mini",
                gemini_action="comment_or_hold",
                shadow_action="approve_and_merge",
                classification="unsafe_merge",
                ttft_ms=180,
                total_ms=1100,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_001_500,
                dispatch_id="z1",
                agent="zannah",
                shadow_model="qwen3.8-27b",
                classification="match",
                ttft_ms=420,
                total_ms=3200,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_002_500,
                dispatch_id="z2",
                agent="zannah",
                shadow_model="qwen3.8-27b",
                gemini_action="approve_and_merge",
                shadow_action="comment_or_hold",
                escalate=True,
                classification="safe_escalation",
                ttft_ms=460,
                total_ms=3600,
            ),
        ]
        model = shadow_report.build_report_model(records, now_ms_fn=lambda: 1_760_000_010_000)
        self.assertTrue(model["is_merged"])
        hosts = model["hosts"]
        assert isinstance(hosts, dict)
        self.assertEqual(set(hosts.keys()), {"skrye", "zannah"})
        self.assertFalse(hosts["skrye"]["hard_gate_passed"])
        self.assertTrue(hosts["zannah"]["hard_gate_passed"])

        scorecard = shadow_report.render_terminal_scorecard(model)
        self.assertIn("Side-by-Side Comparison", scorecard)
        self.assertIn("inkling-2-mini", scorecard)
        self.assertIn("qwen3.8-27b", scorecard)


class TestHtmlDashboardAndSecurity(unittest.TestCase):
    """Verify inline-SVG HTML rendering, Catppuccin Mocha theme, CSP, XSS, and URL validation."""

    def test_single_host_and_empty_state_html_dashboard(self) -> None:
        empty_model = shadow_report.build_report_model(
            [],
            agent="zannah",
            shadow_model="qwen3.8-27b",
            now_ms_fn=lambda: 1_760_000_000_000,
        )
        empty_html = shadow_report.render_html_dashboard(
            empty_model,
            peer_url="https://skrye.drongo-gamma.ts.net/shadow/",
            peer_label="Skrye (inkling-2-mini)",
        )
        self.assertIn(shadow_report.CSP_POLICY, empty_html)
        self.assertIn("#1e1e2e", empty_html)
        self.assertIn("#181825", empty_html)
        self.assertIn("#cdd6f4", empty_html)
        self.assertIn('href="./summary.json"', empty_html)
        self.assertIn('href="https://skrye.drongo-gamma.ts.net/shadow/"', empty_html)
        self.assertIn("No shadow evaluation runs recorded yet", empty_html)
        self.assertIn("Awaiting scored shadow evaluation runs.", empty_html)
        self.assertIn("No shadow latency measurements recorded yet.", empty_html)
        self.assertEqual(empty_html.count("<svg "), 3)
        self.assertNotIn("innerHTML", empty_html)
        # Ensure zero external stylesheet, script, or image requests.
        self.assertIsNone(re.search(r"<(?:script|link|img)[^>]+(?:src|href)=[\"']https?://", empty_html, re.IGNORECASE))

    def test_merged_html_dashboard_and_details_panel(self) -> None:
        records = [
            _make_jsonl_record(
                timestamp_ms=1_760_000_001_000,
                dispatch_id="s1",
                agent="skrye",
                shadow_model="inkling-2-mini",
                number=101,
                classification="match",
                ttft_ms=120,
                total_ms=800,
            ),
            _make_jsonl_record(
                timestamp_ms=1_760_000_002_000,
                dispatch_id="z1",
                agent="zannah",
                shadow_model="qwen3.8-27b",
                number=102,
                gemini_action="rerun_ci",
                shadow_action="comment_or_hold",
                classification="mismatch",
                gemini_commands=["gh run rerun 777 --failed"],
                gemini_reply_excerpt="Retried flaky CI job.",
                reason="Held pending manual review of CI flake.",
                ttft_ms=350,
                total_ms=2600,
            ),
        ]
        model = shadow_report.build_report_model(records, now_ms_fn=lambda: 1_760_000_010_000)
        doc = shadow_report.render_html_dashboard(model)

        self.assertIn("Side-by-Side Host and Model Comparison", doc)
        self.assertIn("qwen3.8-27b", doc)
        self.assertIn("inkling-2-mini", doc)
        self.assertIn('data-filter-host="skrye"', doc)
        self.assertIn('data-filter-host="zannah"', doc)
        self.assertIn('data-filter-classification="unsafe_merge"', doc)
        self.assertIn("<details class=\"compare-details\">", doc)
        self.assertIn("gh run rerun 777 --failed", doc)
        self.assertIn("Retried flaky CI job.", doc)
        self.assertIn("Held pending manual review of CI flake.", doc)
        self.assertIn('href="https://github.com/wimpysworld/demo-app/pull/102" target="_blank" rel="noopener noreferrer"', doc)
        self.assertIn("row.hidden = !show;", doc)
        self.assertNotIn("innerHTML", doc)

    def test_xss_escaping_secret_redaction_and_pr_url_validation(self) -> None:
        xss = '<script>alert("xss")</script>'
        attr_xss = '"><img src=x onerror=alert(1)>'
        secret = "ghp_VerySecretToken1234567890"
        bad_urls = (
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "https://evil.example/wimpysworld/demo/pull/1",
            "https://github.com/../etc/pull/1",
            "https://github.com/wimpysworld/demo/pull/1?x=<script>",
        )
        for bad in bad_urls:
            self.assertFalse(shadow_report.is_valid_pr_url(bad), f"Must reject {bad!r}")
        self.assertTrue(shadow_report.is_valid_pr_url("https://github.com/wimpysworld/demo.repo-1/pull/99"))

        rec = _make_jsonl_record(
            repo=f"wimpysworld/{xss}",
            number=7,
            pr_url="javascript:alert(1)",
            gemini_action="comment_or_hold",
            shadow_action="approve_and_merge",
            classification="unsafe_merge",
            gemini_commands=[f"gh pr comment 7 --body '{secret} {xss}'"],
            gemini_reply_excerpt=f"Reply {attr_xss} {secret}",
            reason=f"Reason {xss} {secret}",
            error=f"Err {attr_xss} {secret}",
        )
        model = shadow_report.build_report_model([rec], now_ms_fn=lambda: 1_760_000_000_000)
        doc = shadow_report.render_html_dashboard(
            model,
            title=f"Dashboard {xss}",
            peer_url="javascript:alert(2)",
            peer_label=f"Peer {attr_xss}",
        )

        self.assertNotIn("<script>alert", doc)
        self.assertNotIn("<img src=x", doc)
        self.assertNotIn('href="javascript:', doc)
        self.assertNotIn(secret, doc)
        self.assertIn("&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;", doc)
        self.assertIn("[redacted]", doc)
        self.assertIn('<span class="pr-plain">', doc)


class TestAtomicWriteAndIndex(unittest.TestCase):
    """Verify atomic 0644 HTML writes, symlink refusal, and --ensure-index behaviour."""

    def test_atomic_write_permissions_and_symlink_refusal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            target = tmp_dir / "index.html"
            written = shadow_report.write_shadow_report_html(target, "<!DOCTYPE html><html></html>\n")
            self.assertEqual(written, target)
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o644)
            self.assertEqual(target.read_text(encoding="utf-8"), "<!DOCTYPE html><html></html>\n")
            # No leftover temp files.
            self.assertEqual([p.name for p in tmp_dir.iterdir()], ["index.html"])

            # Overwrite existing regular file cleanly.
            shadow_report.write_shadow_report_html(target, "<html>updated</html>")
            self.assertEqual(target.read_text(encoding="utf-8"), "<html>updated</html>")

            # Refuse symlink target without modifying real target.
            victim = tmp_dir / "victim.txt"
            victim.write_text("keep-me", encoding="utf-8")
            link = tmp_dir / "link.html"
            link.symlink_to(victim)
            with self.assertRaises(ValueError):
                shadow_report.write_shadow_report_html(link, "<html>pwned</html>")
            self.assertEqual(victim.read_text(encoding="utf-8"), "keep-me")

            # Refuse dangling symlink.
            dangling = tmp_dir / "dangling.html"
            dangling.symlink_to(tmp_dir / "nonexistent-target.html")
            with self.assertRaises(ValueError):
                shadow_report.write_shadow_report_html(dangling, "<html>nope</html>")

            # Refuse directory target.
            sub_dir = tmp_dir / "subdir"
            sub_dir.mkdir()
            with self.assertRaises(ValueError):
                shadow_report.write_shadow_report_html(sub_dir, "<html>nope</html>")

    def test_ensure_index_and_cli_env_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            state_dir = tmp_dir / "state"
            state_dir.mkdir(mode=0o700)
            reports_dir = tmp_dir / "reports"
            summary_path = reports_dir / "summary.json"
            index_path = reports_dir / "index.html"

            env = {
                "MOLTIS_SHADOW_REPORT_AGENT": "skrye",
                "MOLTIS_SHADOW_REPORT_MODEL": "inkling-2-mini",
                "MOLTIS_SHADOW_REPORT_GEMINI_MODEL": "gemini-2.5-pro",
                "MOLTIS_SHADOW_REPORT_STATE_DIR": str(state_dir),
                "MOLTIS_SHADOW_REPORT_SUMMARY_PATH": str(summary_path),
                "MOLTIS_SHADOW_REPORT_TAILNET": "custom.ts.net",
            }
            with patch.dict(os.environ, env, clear=False):
                rc = shadow_report.main(["--ensure-index"])
            self.assertEqual(rc, 0)
            self.assertTrue(index_path.is_file())
            initial_html = index_path.read_text(encoding="utf-8")
            self.assertIn("inkling-2-mini", initial_html)
            self.assertIn("No shadow evaluation runs recorded yet", initial_html)

            # Without --force, existing regular index.html is preserved untouched.
            index_path.write_text("<!-- sentinel -->\n", encoding="utf-8")
            with patch.dict(os.environ, env, clear=False):
                rc2 = shadow_report.main(["--ensure-index"])
            self.assertEqual(rc2, 0)
            self.assertEqual(index_path.read_text(encoding="utf-8"), "<!-- sentinel -->\n")

            # Add a JSONL record and run with --force -> regenerated with record data.
            jsonl_path = state_dir / shadow_eval.SHADOW_EVAL_JSONL_FILENAME
            jsonl_path.write_text(
                json.dumps(_make_jsonl_record(agent="skrye", shadow_model="inkling-2-mini", number=55)) + "\n",
                encoding="utf-8",
            )
            with patch.dict(os.environ, env, clear=False):
                rc3 = shadow_report.main(["--ensure-index", "--force"])
            self.assertEqual(rc3, 0)
            updated_html = index_path.read_text(encoding="utf-8")
            self.assertIn("1 runs", updated_html)
            self.assertNotIn("<!-- sentinel -->", updated_html)

            # Direct helper render_host_report_from_jsonl works cleanly too.
            direct_html = reports_dir / "direct.html"
            model = shadow_report.render_host_report_from_jsonl(
                jsonl_path,
                direct_html,
                agent="skrye",
                shadow_model="inkling-2-mini",
            )
            self.assertEqual(model["totals"]["total"], 1)  # type: ignore[index]
            self.assertTrue(direct_html.is_file())


class TestRemoteFetchAndOpen(unittest.TestCase):
    """Verify read-only Tailscale SSH fetch, local host shortcut, and --fetch --open CLI."""

    def test_fetch_local_and_remote_hosts_with_missing_remote_jsonl(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            xdg_state = Path(tmp) / "state"
            local_dir = xdg_state / "moltis" / "github-companion-skrye"
            local_dir.mkdir(parents=True)
            local_rec = _make_jsonl_record(agent="skrye", shadow_model="inkling-2-mini", dispatch_id="local-1")
            (local_dir / shadow_eval.SHADOW_EVAL_JSONL_FILENAME).write_text(
                json.dumps(local_rec) + "\n",
                encoding="utf-8",
            )

            zannah_rec = _make_jsonl_record(agent="zannah", shadow_model="qwen3.8-27b", dispatch_id="remote-1")
            seen_cmds: list[list[str]] = []

            def fake_runner(cmd: list[str], **_kwargs: object) -> subprocess.CompletedProcess:
                seen_cmds.append(list(cmd))
                if "zannah.drongo-gamma.ts.net" in cmd:
                    return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(zannah_rec) + "\n", stderr="")
                # Missing remote JSONL tolerated as empty output.
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

            with patch.dict(os.environ, {"XDG_STATE_HOME": str(xdg_state)}, clear=False):
                records = shadow_report.fetch_remote_shadow_records(
                    ["skrye", "zannah", "traya"],
                    tailnet="drongo-gamma.ts.net",
                    runner=fake_runner,
                    local_hostname="skrye",
                )

            # Local host skrye did NOT use SSH; zannah and traya did.
            self.assertEqual(len(seen_cmds), 2)
            self.assertEqual(
                seen_cmds[0][:6],
                ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "--"],
            )
            self.assertEqual(seen_cmds[0][6], "zannah.drongo-gamma.ts.net")
            self.assertIn("github-companion-zannah/shadow-eval.jsonl", seen_cmds[0][7])
            self.assertEqual([r["dispatch_id"] for r in records], ["local-1", "remote-1"])

            # Invalid host name rejected to prevent option injection.
            with self.assertRaises(ValueError):
                shadow_report.fetch_remote_shadow_records(["-oProxyCommand=id"], runner=fake_runner)

    def test_cli_fetch_and_open_defaults_to_comparison_html(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fake_home = Path(tmp)
            skrye_rec = _make_jsonl_record(agent="skrye", shadow_model="inkling-2-mini", dispatch_id="f-s1")
            zannah_rec = _make_jsonl_record(
                agent="zannah",
                shadow_model="qwen3.8-27b",
                dispatch_id="f-z1",
                gemini_action="approve_and_merge",
                shadow_action="comment_or_hold",
                classification="safe_escalation",
            )
            recorded_cmds: list[list[str]] = []

            def fake_subprocess_run(cmd: list[str], **_kwargs: object) -> subprocess.CompletedProcess:
                recorded_cmds.append(list(cmd))
                if cmd[0] == "ssh":
                    target = cmd[6]
                    if target.startswith("skrye."):
                        return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(skrye_rec) + "\n", stderr="")
                    if target.startswith("zannah."):
                        return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(zannah_rec) + "\n", stderr="")
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

            stdout_buf = io.StringIO()
            with (
                patch.dict(os.environ, {"HOME": str(fake_home)}, clear=False),
                patch("socket.gethostname", return_value="vader"),
                patch("subprocess.run", side_effect=fake_subprocess_run),
                patch("sys.stdout", stdout_buf),
            ):
                rc = shadow_report.main(["--fetch", "--open"])

            self.assertEqual(rc, 0)
            expected_html = fake_home / "Volatile" / "moltis-shadow-reports" / "comparison.html"
            self.assertTrue(expected_html.is_file())
            rendered_html = expected_html.read_text(encoding="utf-8")
            self.assertIn("inkling-2-mini", rendered_html)
            self.assertIn("qwen3.8-27b", rendered_html)
            self.assertIn("Side-by-Side Comparison", stdout_buf.getvalue())

            expected_opener = "open" if sys.platform == "darwin" else "xdg-open"
            self.assertEqual(len(recorded_cmds), 3)
            self.assertEqual(recorded_cmds[2], [expected_opener, str(expected_html)])


if __name__ == "__main__":
    unittest.main()
