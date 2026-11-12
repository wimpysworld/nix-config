# The gh-pr-watch package build runs these offline contract tests.
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import pty
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


SOURCE = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).with_name("gh-pr-watch.py")
spec = importlib.util.spec_from_file_location("watcher", SOURCE)
watcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watcher)
URL = "https://github.com/example/project/pull/12"


def responses():
    return [
        {"data": {"repository": {"pullRequest": {
            "state": "OPEN", "headRefOid": "abc", "isDraft": False,
            "reviewDecision": "APPROVED", "mergeStateStatus": "CLEAN",
            "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "SUCCESS"}}}]},
        }}}},
        [{"data": {"repository": {"pullRequest": {"reviewThreads": {
            "nodes": [{"id": "thread", "isResolved": True, "isOutdated": False}]
        }}}}}],
        [[{"id": 1, "body": "review", "state": "APPROVED", "commit_id": "abc"}]],
        [[{"id": 2, "body": "comment", "path": "file", "updated_at": "yesterday"}]],
        {"users": [{"login": "reviewer"}], "teams": []},
    ]


class SnapshotTests(unittest.TestCase):
    def digest(self, values):
        with patch.object(watcher, "request", side_effect=values) as api:
            result = watcher.snapshot(URL)
        for call in api.call_args_list:
            self.assertNotIn("--method", call.args)
        return result["digest"]

    def test_semantic_changes_wake_the_watch(self):
        baseline = self.digest(responses())
        variants = []
        for field, value in [("headRefOid", "def"), ("state", "MERGED"), ("reviewDecision", "CHANGES_REQUESTED")]:
            data = responses()
            data[0]["data"]["repository"]["pullRequest"][field] = value
            variants.append(data)
        data = responses()
        data[0]["data"]["repository"]["pullRequest"]["commits"]["nodes"][0]["commit"]["statusCheckRollup"]["state"] = "FAILURE"
        variants.append(data)
        data = responses()
        data[1][0]["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"][0]["isResolved"] = False
        variants.append(data)
        data = responses()
        data[3][0][0]["body"] = "edited finding"
        variants.append(data)
        data = responses()
        data[2].append([{"id": 3, "body": "new page", "state": "COMMENTED"}])
        variants.append(data)
        for data in variants:
            self.assertNotEqual(baseline, self.digest(data))

    def test_volatile_fields_do_not_wake_the_watch(self):
        data = responses()
        data[3][0][0]["updated_at"] = "today"
        self.assertEqual(self.digest(responses()), self.digest(data))

    def test_seed_prevents_first_read_race_and_error_changes_output(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            watcher.write_result(directory, {"seed": True, "digest": "baseline"})
            with patch.object(watcher, "snapshot", side_effect=ValueError("secret diagnostic")) as api:
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    watcher.sample(URL, directory)
                api.assert_not_called()
                self.assertEqual(output.getvalue().strip(), "baseline")
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    watcher.sample(URL, directory)
                self.assertEqual(output.getvalue().strip(), "ERROR")
                self.assertNotIn("secret", (directory / "result.json").read_text())
                self.assertEqual((directory / "result.json").stat().st_mode & 0o777, 0o600)

    def test_url_cannot_select_another_endpoint_or_shell_command(self):
        for url in [URL + "/files", URL + ";id", URL.replace("github.com", "evil.example"), URL.replace("example/", "../")]:
            with self.assertRaises(ValueError):
                watcher.identity(url)

    def test_interrupt_cleans_the_native_process_group(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name) / "state"
            process = Mock(pid=12345)
            process.wait.side_effect = [KeyboardInterrupt(), 0]
            with (
                patch.object(sys, "argv", [str(SOURCE), URL, "--state-dir", str(directory)]),
                patch.object(sys.stdin, "isatty", return_value=True),
                patch.object(sys.stdout, "isatty", return_value=True),
                patch.object(watcher, "snapshot", return_value={"digest": "baseline"}),
                patch.object(subprocess, "Popen", return_value=process),
                patch.object(watcher.signal, "signal"),
                patch.object(os, "killpg") as kill,
            ):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    with patch.object(output, "isatty", return_value=True):
                        code = watcher.main()
            self.assertEqual(code, 130)
            kill.assert_called_once_with(12345, watcher.signal.SIGTERM)
            self.assertEqual(json.loads((directory / "result.json").read_text())["status"], "interrupted")


class NativeWatchTests(unittest.TestCase):
    def run_watch(self, changed=False, error=False):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            mock = directory / "gh-api-safe"
            data = responses()
            mock.write_text(
                "#!" + sys.executable + "\n"
                "import json,sys\nfrom pathlib import Path\n"
                "data=" + repr(data) + "\n"
                "counter=Path(" + repr(str(directory / "counter")) + ")\n"
                "n=int(counter.read_text()) if counter.exists() else 0\n"
                "counter.write_text(str(n+1))\n"
                + ("sys.exit(7) if n>=5 else None\n" if error else "")
                + ("data[0]['data']['repository']['pullRequest']['state']='MERGED' if n>=5 else 'OPEN'\n" if changed else "")
                + "print(json.dumps(data[n%5]))\n"
            )
            mock.chmod(0o700)
            master, slave = pty.openpty()
            try:
                process = subprocess.Popen(
                    [sys.executable, str(SOURCE), URL, "--state-dir", str(directory / "state"), "--timeout", "3", "--interval", "1"],
                    stdin=slave, stdout=slave, stderr=slave,
                    env={**os.environ, "PATH": str(directory) + os.pathsep + os.environ["PATH"]},
                )
                process.wait(timeout=10)
                output = os.read(master, 10000)
                result = json.loads((directory / "state" / "result.json").read_text())
                return process.returncode, result, output
            finally:
                os.close(master)
                os.close(slave)

    def test_native_watch_returns_changed(self):
        code, result, _ = self.run_watch(changed=True)
        self.assertEqual(code, 0)
        self.assertEqual(result["status"], "changed")
        self.assertEqual(result["state"], "MERGED")

    def test_native_watch_timeout_is_not_success(self):
        code, result, _ = self.run_watch()
        self.assertEqual(code, 124)
        self.assertEqual(result["status"], "timeout")

    def test_native_watch_error_is_not_success(self):
        code, result, _ = self.run_watch(error=True)
        self.assertEqual(code, 1)
        self.assertEqual(result["status"], "error")


if __name__ == "__main__":
    unittest.main()
