import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from migrate import BACKUP, REGISTRY, migrate


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name).resolve()
        self.data = self.home / ".moltis"
        self.data.mkdir()
        self.registry = self.data / REGISTRY
        self.backup = self.data / BACKUP

    def write_registry(self):
        value = {
            "unknown": {
                "keep": [1, True, "value"],
                "high_surrogate": "\ud800",
                "low_surrogate": "\udc00",
                "unicode": "café 日本語 😀",
            },
            "servers": {
                "remote": {"url": "https://example.invalid/mcp", "headers": {"Authorization": "synthetic-secret"}},
                "local": {"command": "example", "enabled": True, "extra": {"keep": 1}},
                "disabled": {"enabled": False},
            },
        }
        self.registry.write_text(json.dumps(value))
        return value

    def test_absent(self):
        migrate(self.data)
        migrate(self.home / "absent")
        self.assertEqual(list(self.data.iterdir()), [])

    def test_preserves_fields_and_backup_idempotently(self):
        expected = self.write_registry()
        original = self.registry.read_bytes()
        migrate(self.data)
        for server in expected["servers"].values():
            server["enabled"] = False
        self.assertEqual(json.loads(self.registry.read_bytes()), expected)
        self.assertEqual(self.backup.read_bytes(), original)
        first = self.registry.stat()
        migrate(self.data)
        self.assertEqual(self.registry.stat().st_ino, first.st_ino)
        self.assertEqual(self.backup.read_bytes(), original)
        for path in (self.registry, self.backup):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_existing_backup_is_not_overwritten(self):
        self.write_registry()
        self.backup.write_bytes(b"previous backup")
        self.backup.chmod(0o600)
        migrate(self.data)
        self.assertEqual(self.backup.read_bytes(), b"previous backup")

    def test_reenabled_server_is_disabled_again(self):
        self.write_registry()
        migrate(self.data)
        backup = self.backup.read_bytes()
        self.write_registry()
        migrate(self.data)
        self.assertEqual(self.backup.read_bytes(), backup)
        self.assertTrue(all(not server["enabled"] for server in json.loads(self.registry.read_bytes())["servers"].values()))

    def test_invalid_data_fails_without_changes(self):
        for content in (b"synthetic-secret", b"[]", b'{"servers": []}', b'{"servers":{"x":null}}',
                        b'{"servers":{"x":{"enabled":"false"}}}', b'{"servers":{},"servers":{}}', b'{"unknown":NaN}'):
            with self.subTest(content=content):
                self.registry.write_bytes(content)
                with self.assertRaises((ValueError, UnicodeError)):
                    migrate(self.data)
                self.assertEqual(self.registry.read_bytes(), content)
                self.assertFalse(self.backup.exists())

    def test_writable_data_directory_refused_without_changes(self):
        self.write_registry()
        original = self.registry.read_bytes()
        original_stat = self.registry.stat()
        for mode in (0o770, 0o707, 0o777):
            with self.subTest(mode=mode):
                self.data.chmod(mode)
                with self.assertRaisesRegex(ValueError, "Unsafe data directory"):
                    migrate(self.data)
                self.assertEqual(self.registry.read_bytes(), original)
                self.assertEqual(self.registry.stat(), original_stat)
                self.assertEqual(stat.S_IMODE(self.data.stat().st_mode), mode)
                self.assertEqual(list(self.data.iterdir()), [self.registry])

    def test_wrong_data_directory_owner_refused_without_changes(self):
        self.write_registry()
        original = self.registry.read_bytes()
        original_stat = self.registry.stat()
        with (
            patch("migrate.os.getuid", return_value=os.getuid() + 1),
            self.assertRaisesRegex(ValueError, "Unsafe data directory"),
        ):
            migrate(self.data)
        self.assertEqual(self.registry.read_bytes(), original)
        self.assertEqual(self.registry.stat(), original_stat)
        self.assertEqual(list(self.data.iterdir()), [self.registry])

    def test_registry_symlink_refused(self):
        target = self.home / "target"
        target.write_text('{"servers": {}}')
        self.registry.symlink_to(target)
        with self.assertRaises(OSError):
            migrate(self.data)
        self.assertEqual(target.read_text(), '{"servers": {}}')

    def test_parent_symlink_refused(self):
        link = self.home / "link"
        link.symlink_to(self.data, target_is_directory=True)
        with self.assertRaises(OSError):
            migrate(link)

    def test_backup_symlink_refused(self):
        self.write_registry()
        original = self.registry.read_bytes()
        self.backup.symlink_to(self.home / "missing")
        with self.assertRaises(OSError):
            migrate(self.data)
        self.assertEqual(self.registry.read_bytes(), original)

    def test_hardlink_refused(self):
        self.write_registry()
        os.link(self.registry, self.home / "alias")
        with self.assertRaises(ValueError):
            migrate(self.data)

    def test_private_permissions_when_already_disabled(self):
        self.registry.write_text('{"servers":{"x":{"enabled":false}}}')
        self.registry.chmod(0o644)
        migrate(self.data)
        self.assertEqual(stat.S_IMODE(self.registry.stat().st_mode), 0o600)

    def test_cli_error_does_not_expose_data(self):
        self.registry.write_text("synthetic-secret")
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("migrate.py")), str(self.data)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("synthetic-secret", result.stderr)
        self.assertIn("Gateway startup stopped", result.stderr)


if __name__ == "__main__":
    unittest.main()
