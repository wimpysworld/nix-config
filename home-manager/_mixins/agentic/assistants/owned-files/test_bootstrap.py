"""Check old-generation ownership proofs with synthetic scripts and fake secrets."""

import importlib.util
import json
from pathlib import Path
import plistlib
import shlex
import tempfile
import unittest
from unittest import mock


module_spec = importlib.util.spec_from_file_location("owned_bootstrap", Path(__file__).with_name("bootstrap.py"))
bootstrap = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(bootstrap)


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="bootstrap-tests-")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.root = self.home / ".codex"
        self.root.mkdir()
        self.target = self.root / "skills/fixture/SKILL.md"
        self.target.parent.mkdir(parents=True)

    def test_literal_public_writer_proves_exact_bytes_and_symlink_target(self):
        content = "---\nname: fixture\n---\nA user's $literal `text`.\n"
        self.target.write_text(content)
        link = self.target.parent / "references"
        link.symlink_to("/nix/store/fixture/references")
        script = f"mkdir -p {shlex.quote(str(self.target.parent))}\nprintf '%s' {shlex.quote(content)} > {shlex.quote(str(self.target))}\nln -sfn /nix/store/fixture/references {shlex.quote(str(link))}\n"
        expected = bootstrap.parse_public(script)
        verified = bootstrap.verified_records(expected, [str(self.root)])
        self.assertEqual(set(verified), {str(self.target), str(link)})
        self.target.write_text("User modification.\n")
        self.assertEqual(set(bootstrap.verified_records(expected, [str(self.root)])), {str(link)})

    def test_only_declared_real_directories_are_captured(self):
        declared = self.target.parent
        manual = self.root / "manual"
        manual.mkdir()
        alias = self.root / "alias"
        alias.symlink_to(manual, target_is_directory=True)
        directories = set()
        bootstrap.parse_public(f"mkdir -p {declared}\nmkdir -p {alias}\n", directories)
        verified = bootstrap.verified_directories(directories, [str(self.root)])
        self.assertEqual(set(verified), {str(declared)})
        self.assertNotIn(str(manual), verified)

    def secret_script(self, source):
        return f"if [ -r {shlex.quote(str(source))} ]; then\nmkdir -p {shlex.quote(str(self.target.parent))}\nprintf '%s' 'Prefix\n' > {shlex.quote(str(self.target))}\ncat {shlex.quote(str(source))} >> {shlex.quote(str(self.target))}\nelse\necho 'Missing fake secret.' >&2\nfi\n"

    def test_secret_writer_requires_matching_prefix_and_fake_secret(self):
        source = self.home / ".config/sops-nix/secrets/fake"
        source.parent.mkdir(parents=True)
        source.write_text("Fake body.\n")
        self.target.write_text("Prefix\nFake body.\n")
        expected = bootstrap.parse_secrets(self.secret_script(source), str(self.home))
        self.assertEqual(set(bootstrap.verified_records(expected, [str(self.root)])), {str(self.target)})
        self.target.write_text("Prefix\nUser modification.\n")
        self.assertEqual(bootstrap.verified_records(expected, [str(self.root)]), {})

    def test_missing_secret_does_not_prove_the_existing_copy(self):
        source = self.home / ".config/sops-nix/secrets/missing"
        self.target.write_text("Prefix\nExisting content.\n")
        self.assertEqual(bootstrap.parse_secrets(self.secret_script(source), str(self.home)), {})

    def test_secret_source_outside_runtime_root_is_rejected_before_reading(self):
        with self.assertRaises(bootstrap.Unsupported):
            bootstrap.parse_secrets(self.secret_script(self.home / "outside"), str(self.home))

    def test_unknown_shell_command_is_not_executed_or_partially_adopted(self):
        marker = self.home / "must-not-exist"
        with self.assertRaises(bootstrap.Unsupported):
            bootstrap.parse_public(f"printf '%s' generated > {self.target}\ntouch {marker}\n")
        self.assertFalse(marker.exists())

    def test_symlink_parent_and_outside_destination_are_not_proof(self):
        outside = self.home / "outside"
        outside.mkdir()
        target = outside / "SKILL.md"
        target.write_text("Generated content.\n")
        alias = self.root / "alias"
        alias.symlink_to(outside, target_is_directory=True)
        record = bootstrap.fingerprint(target.read_bytes())
        self.assertEqual(bootstrap.verified_records({str(alias / "SKILL.md"): record, str(target): record}, [str(self.root)]), {})

    def test_existing_manifest_prevents_repeated_bootstrap(self):
        state = self.home / "state"
        state.mkdir()
        (state / "manifest.json").write_text("{}")
        self.assertEqual(bootstrap.capture({"stateDir": str(state)}, "/not/read"), {})

    def test_old_sops_template_link_is_proved_and_replaced_after_refresh(self):
        generation = self.home / "old-generation"
        service = generation / "home-files/.config/systemd/user/sops-nix.service"
        service.parent.mkdir(parents=True)
        runner = self.home / "sops-runner"
        manifest = self.home / "sops-manifest.json"
        old_runtime = self.home / ".config/sops-nix/secrets"
        source = old_runtime / "rendered/assistant-codex-skill-fixture"
        source.parent.mkdir(parents=True)
        source.write_text("Fake old template.\n")
        destination = self.root / "skills/fixture/template.md"
        destination.symlink_to(source)
        manifest.write_text(json.dumps({
            "symlinkPath": str(old_runtime), "secrets": [],
            "templates": [{"name": "assistant-codex-skill-fixture", "path": str(destination)}],
        }))
        runner.write_text(f"/nix/store/fake/bin/sops-install-secrets -ignore-passwd {manifest}\n")
        service.write_text(f"[Service]\nExecStart={runner}\n")
        with mock.patch.object(bootstrap, "store_path", return_value=True):
            records = bootstrap.old_secret_links(generation, [str(self.root)])
        verified = bootstrap.verified_records(records, [str(self.root)])
        self.assertEqual(verified, {str(destination): {"kind": "symlink", "target": str(source)}})
        state = self.home / "state"
        state.mkdir(mode=0o700)
        captured = state / "bootstrap.json"
        captured.write_text(json.dumps({"version": 1, "files": verified}))
        captured.chmod(0o600)
        new_source = self.home / "new-rendered-template"
        new_source.write_text("Fake new template.\n")
        module_spec = importlib.util.spec_from_file_location("deploy_template", Path(__file__).with_name("deploy.py"))
        deploy = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(deploy)
        spec = {"version": 1, "stateDir": str(state), "roots": [str(self.root)], "files": [
            {"kind": "symlink", "path": str(destination), "source": str(new_source)},
        ]}
        with self.assertRaises(deploy.Conflict):
            deploy.deploy(spec)
        deploy.deploy(spec, bootstrap_manifest=str(captured))
        self.assertEqual(destination.readlink(), new_source)

    def test_retry_keeps_prior_proof_when_secret_content_changes(self):
        state = self.home / "state"
        state.mkdir(mode=0o700)
        self.target.write_text("Fake old copied secret.\n")
        record = bootstrap.fingerprint(self.target.read_bytes())
        captured = state / "bootstrap.json"
        captured.write_text(json.dumps({"version": 1, "files": {str(self.target): record}}))
        captured.chmod(0o600)
        spec = self.home / "spec.json"
        spec.write_text(json.dumps({"stateDir": str(state), "roots": [str(self.root)], "home": str(self.home)}))
        with mock.patch.object(bootstrap, "capture", return_value={}):
            with mock.patch("sys.argv", ["bootstrap.py", str(spec), "--output", str(captured)]):
                bootstrap.main()
        self.assertEqual(json.loads(captured.read_text())["files"], {str(self.target): record})

    def darwin_fixture(self, direct_launcher=False):
        generation = self.home / "darwin-generation"
        plist = generation / "LaunchAgents/org.nix-community.home.sops-nix.plist"
        plist.parent.mkdir(parents=True)
        manifest = self.home / "darwin-sops-manifest.json"
        runtime = self.home / ".config/sops-nix/secrets"
        target = self.root / "skills/fixture/template.md"
        manifest.write_text(json.dumps({
            "symlinkPath": str(runtime), "secrets": [],
            "templates": [{"name": "assistant-codex-skill-fixture", "path": str(target)}],
        }))
        script = self.home / "sops install script"
        script.write_text(f"/nix/store/fake/bin/sops-install-secrets -ignore-passwd {shlex.quote(str(manifest))}\n")
        if direct_launcher:
            launcher = self.home / "launcher/bin/sops-nix"
            launcher.parent.mkdir(parents=True)
            launcher.write_text(f"#!/bin/sh\nexec {shlex.quote(str(script))}\n")
            arguments = [str(launcher)]
        else:
            arguments = ["/bin/sh", "-c", f"/bin/wait4path /nix/store && exec {shlex.quote(str(script))}"]
        plist.write_bytes(plistlib.dumps({"ProgramArguments": arguments}))
        return generation, plist, target, runtime / "rendered/assistant-codex-skill-fixture"

    def test_darwin_wait4path_plist_recovers_template_link_without_execution(self):
        generation, _, target, source = self.darwin_fixture()
        with mock.patch.object(bootstrap, "store_path", return_value=True):
            records = bootstrap.old_secret_links(generation, [str(self.root)])
        self.assertEqual(records, {str(target): {"kind": "symlink", "target": str(source)}})
        self.assertFalse(target.exists())

    def test_darwin_direct_launcher_recovers_template_link_without_execution(self):
        generation, _, target, source = self.darwin_fixture(direct_launcher=True)
        with mock.patch.object(bootstrap, "store_path", return_value=True):
            records = bootstrap.old_secret_links(generation, [str(self.root)])
        self.assertEqual(records, {str(target): {"kind": "symlink", "target": str(source)}})
        self.assertFalse(target.exists())

    def test_darwin_plist_rejects_extra_shell_commands(self):
        generation, plist, _, _ = self.darwin_fixture()
        data = plistlib.loads(plist.read_bytes())
        marker = self.home / "must-not-exist"
        data["ProgramArguments"][2] += f"; touch {marker}"
        plist.write_bytes(plistlib.dumps(data))
        with mock.patch.object(bootstrap, "store_path", return_value=True):
            with self.assertRaises(bootstrap.Unsupported):
                bootstrap.old_secret_links(generation, [str(self.root)])
        self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
