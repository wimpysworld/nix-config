# Gate: just build-home builds the startup helper and runs these fixture tests.
import importlib.util
from pathlib import Path
import stat
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("merge_startup", sys.argv.pop(1))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class MergeStartupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "Scripts" / "__startup.lua"
        self.path.parent.mkdir()

    def backups(self):
        return list(self.path.parent.glob("__startup.lua.backup-*"))

    def test_first_install_and_repeat(self):
        helper.merge_startup(self.path)
        original = self.path.read_bytes()
        metadata = self.path.stat()
        helper.merge_startup(self.path)
        self.assertIn(helper.LOAD, original)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(self.path.stat().st_ino, metadata.st_ino)
        self.assertEqual(self.path.stat().st_mtime_ns, metadata.st_mtime_ns)
        self.assertEqual(self.backups(), [])

    def test_preserves_user_code_and_backs_up_only_changes(self):
        original = b'-- user startup\nprint("hello")'
        self.path.write_bytes(original)
        helper.merge_startup(self.path)
        self.assertTrue(self.path.read_bytes().startswith(original + b"\n"))
        self.assertEqual([p.read_bytes() for p in self.backups()], [original])
        helper.merge_startup(self.path)
        self.assertEqual(len(self.backups()), 1)

    def test_replaces_only_marked_block(self):
        prefix, suffix = b"user_before()\n", b"user_after()\n"
        self.path.write_bytes(prefix + helper.START + b"\nold()\n" + helper.END + b"\n" + suffix)
        helper.merge_startup(self.path)
        updated = self.path.read_bytes()
        self.assertTrue(updated.startswith(prefix))
        self.assertTrue(updated.endswith(suffix))
        self.assertNotIn(b"old()", updated)
        self.assertEqual(updated.count(helper.LOAD), 1)

    def test_preserves_crlf_and_non_utf8_bytes(self):
        original = b"-- user byte: \xff\r\nuser()\r\n"
        self.path.write_bytes(original)
        helper.merge_startup(self.path)
        updated = self.path.read_bytes()
        self.assertTrue(updated.startswith(original))
        self.assertNotIn(b"\n", updated.replace(b"\r\n", b""))

    def test_rejects_invalid_blocks_without_changes(self):
        for original in [helper.START + b"\n", helper.END + b"\n", helper.END + b"\n" + helper.START + b"\n", (helper.START + b"\n" + helper.END + b"\n") * 2]:
            with self.subTest(original=original):
                self.path.write_bytes(original)
                with self.assertRaises(ValueError):
                    helper.merge_startup(self.path)
                self.assertEqual(self.path.read_bytes(), original)
                self.assertEqual(self.backups(), [])

    def test_rejects_symlinks_without_touching_target(self):
        target = self.path.parent / "user.lua"
        target.write_bytes(b"user()")
        self.path.symlink_to(target)
        with self.assertRaises(ValueError):
            helper.merge_startup(self.path)
        self.assertEqual(target.read_bytes(), b"user()")
        self.assertTrue(self.path.is_symlink())

    def test_retains_permissions_and_previous_backups(self):
        self.path.write_bytes(b"user()\n")
        self.path.chmod(0o600)
        previous = self.path.parent / "__startup.lua.backup-existing"
        previous.write_bytes(b"old backup")
        helper.merge_startup(self.path)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)
        self.assertEqual(previous.read_bytes(), b"old backup")
        self.assertEqual(len(self.backups()), 2)


if __name__ == "__main__":
    unittest.main()
