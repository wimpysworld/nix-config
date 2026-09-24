"""Gate: the Markdown Home Manager package runs these tests during its build."""

import argparse
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "marp_export", Path(__file__).with_name("export.py")
)
assert SPEC and SPEC.loader
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.image = self.root / "a space.png"
        self.image.write_bytes(b"image bytes")
        self.assets = exporter.Assets(self.root, trusted=True)

    def test_local_assets_need_explicit_trust(self):
        with self.assertRaises(exporter.ExportError):
            exporter.Assets(self.root).embed("a%20space.png")
        self.assertEqual(
            self.assets.embed("a%20space.png"),
            exporter.data_uri(b"image bytes", "image/png"),
        )

    def test_remote_absolute_and_escape_paths_fail(self):
        for value in (
            "https://example.test/a.png",
            "//example.test/a.png",
            "file:///etc/passwd",
            "/etc/passwd",
            "../secret.png",
            "%2fetc/passwd",
            "a%20space.png?query",
            "a\\space.png",
            "https:\\example.test/a.png",
        ):
            with self.subTest(value=value), self.assertRaises(exporter.ExportError):
                self.assets.embed(value)

    def test_symlinks_fail_even_inside_root(self):
        link = self.root / "link.png"
        link.symlink_to(self.image)
        with self.assertRaises(exporter.ExportError):
            self.assets.embed("link.png")
        directory = self.root / "linked"
        directory.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(exporter.ExportError):
            exporter.plain_path(directory / "output")

    def test_css_assets_are_embedded(self):
        result = self.assets.css("background: url('a%20space.png')")
        self.assertIn("data:image/png;base64,", result)
        for value in (
            '@import "https://example.test/x.css";',
            r"background:u\72l(https://example.test/a.png)",
            'background:image-set("https://example.test/a.png" 1x)',
            "background:url(//example.test/a.png)",
        ):
            with self.subTest(value=value), self.assertRaises(exporter.ExportError):
                self.assets.css(value)

    def test_css_keeps_marp_selectors_and_string_escapes(self):
        selector = r"div#\:\$p > svg > foreignObject > section"
        css = selector + r'{width:1280px;height:720px;content:"\2192"}'
        parser = exporter.OfflineHTML(self.assets)
        parser.feed("<style>" + css + '</style><div id=":$p"></div>')
        self.assertIn("<style>" + css + "</style>", "".join(parser.parts))
        self.assertEqual(
            self.assets.css(selector + r'{background:url("a\20 space.png")}'),
            selector
            + '{background:url("'
            + exporter.data_uri(b"image bytes", "image/png")
            + '")}',
        )

    def test_escaped_css_resource_functions_fail_closed(self):
        for css in (
            r'background:u\72l("a%20space.png")',
            r'background:\75rl("https://example.test/a.png")',
            r'@\69mport "https://example.test/a.css";',
            r'background:im\61ge-set("https://example.test/a.png" 1x)',
        ):
            with self.subTest(css=css), self.assertRaises(exporter.ExportError):
                self.assets.css(css)

    def test_svg_must_be_self_contained_and_passive(self):
        self.assets.embed(
            exporter.data_uri(
                b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>',
                "image/svg+xml",
            )
        )
        for body in (
            b"<svg><script>alert(1)</script></svg>",
            b'<svg><image href="https://example.test/a.png"/></svg>',
            b'<svg><style>@import "other.css";</style></svg>',
            b'<!DOCTYPE svg [<!ENTITY a "expanded">]><svg>&a;</svg>',
            b'<!DOCTYPE svg SYSTEM "file:///etc/passwd"><svg/>',
            b'<?xml-stylesheet href="https://example.test/a.css"?><svg/>',
            "<!DOCTYPE svg><svg/>".encode("utf-16"),
        ):
            with (
                self.subTest(body=body),
                self.assertRaises((exporter.ExportError, UnicodeError)),
            ):
                self.assets.embed(exporter.data_uri(body, "image/svg+xml"))

    def test_html_rewrites_images_and_counts_unpaginated_slides(self):
        parser = exporter.OfflineHTML(self.assets)
        parser.feed(
            '<section id="1" data-size="16:9"><img src="a%20space.png"><style>p{background:url("a%20space.png")}</style><script>const x = "&amp;";</script></section>'
            '<section data-size="16:9" data-marpit-advanced-background="background"></section>'
            '<section id="2" data-size="16:9" data-marpit-pagination="2"></section>'
        )
        result = "".join(parser.parts)
        self.assertEqual(result.count("data:image/png;base64,"), 2)
        self.assertIn('const x = "&amp;";', result)
        self.assertEqual(parser.slides, 2)

    def test_active_html_and_external_resources_fail(self):
        for body in (
            '<iframe src="a.html">',
            '<img srcset="a.png 1x">',
            '<img src="https://example.test/a.png">',
            '<base href="https://example.test">',
            '<link rel="stylesheet" href="a.css">',
            '<a href="javascript:alert(1)">',
            '<svg><image href="https://example.test/a.png"></svg>',
        ):
            with self.subTest(body=body), self.assertRaises(exporter.ExportError):
                exporter.OfflineHTML(self.assets).feed(body)

    def test_installed_script_symlink_keeps_sibling_theme(self):
        skill = self.root / "installed-skill"
        (skill / "scripts").mkdir(parents=True)
        (skill / "assets/theme").mkdir(parents=True)
        theme = skill / "assets/theme/catppuccin.css"
        theme.write_text("/* installed theme */")
        script = skill / "scripts/export.py"
        script.symlink_to(Path(__file__).with_name("export.py").absolute())
        spec = importlib.util.spec_from_file_location("installed_export", script)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.THEME, theme)
        self.assertEqual(module.THEME.read_text(), "/* installed theme */")

    def test_missing_font_does_not_use_fontconfig_fallback(self):
        with (
            patch.object(exporter, "run", return_value="Other Font\n/not/a/font.ttf"),
            self.assertRaises(exporter.ExportError),
        ):
            exporter.font_css()


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.deck = self.root / "deck with spaces.md"
        self.deck.write_text("# Deck\n")
        self.theme = self.root / "theme.css"
        self.theme.write_text("/* @theme test */")
        self.args = argparse.Namespace(
            input=self.deck,
            out=self.root / "out",
            formats=None,
            browser_path="/browser with spaces/chromium",
            trusted_local_assets=False,
        )
        self.calls = []
        self.environments = []
        self.fail_pdf = False
        self.remote = False

    def fake_run(self, args, **kwargs):
        self.calls.append(args)
        if "--output" in args:
            self.environments.append(kwargs["env"])
            if kwargs["env"].get("MARP_USER") == "1":
                self.assertEqual(kwargs["env"]["TMPDIR"], str(kwargs["cwd"]))
                self.assertEqual(Path(kwargs["cwd"]).stat().st_mode & 0o777, 0o700)
        if "--help" in args:
            return "--theme --pdf --pptx --images --notes --pptx-editable"
        if "--version" in args:
            return "Marp test version"
        destination = Path(args[args.index("--output") + 1])
        if destination.suffix == ".html":
            destination.write_text(
                '<html><head></head><body><section id="1" data-size="16:9">'
                + ('<img src="https://example.test/a.png">' if self.remote else "")
                + "</section></body></html>"
            )
        elif "--pdf" in args and self.fail_pdf:
            raise subprocess.CalledProcessError(1, args, stderr="browser failed")
        elif "--images" in args:
            destination.with_name(
                destination.stem + ".001" + destination.suffix
            ).write_bytes(b"image")
        else:
            destination.write_bytes(b"output")
        return ""

    def do_export(self):
        with (
            patch.object(exporter, "THEME", self.theme),
            patch.object(exporter, "font_css", return_value=""),
            patch.object(exporter, "run", side_effect=self.fake_run),
            patch.object(exporter.shutil, "which", return_value="/bin/soffice"),
        ):
            exporter.export(self.args)

    def test_all_formats_and_safe_argument_boundaries(self):
        self.do_export()
        self.assertEqual(len(list(self.args.out.iterdir())), len(exporter.FORMATS) + 1)
        html = (self.args.out / "deck with spaces.html").read_text()
        self.assertIn("Content-Security-Policy", html)
        self.assertIn("connect-src", html)
        for call in self.calls:
            if "--output" in call:
                self.assertEqual(call[-2:], ["--", str(self.deck)])
                self.assertIn("--no-config-file", call)
                self.assertIn("--html=false", call)
                self.assertNotIn("--allow-local-files", call)
        editable = next(call for call in self.calls if "--pptx-editable" in call)
        self.assertIn("--pptx", editable)

    def test_fenced_exports_use_private_tmpdir_without_changing_home(self):
        self.args.trusted_local_assets = True
        with (
            patch.object(exporter.sys, "platform", "linux"),
            patch.dict(os.environ, {"CHROME_NO_SANDBOX": "1", "MARP_USER": ""}),
        ):
            original = os.environ.copy()
            self.do_export()
            self.assertEqual(dict(os.environ), original)
        for env in self.environments:
            self.assertEqual(env.get("HOME"), original.get("HOME"))
            self.assertEqual(env["MARP_USER"], "1")
            self.assertFalse(Path(env["TMPDIR"]).exists())

    def test_tmpdir_workaround_requires_trust_and_sandbox_opt_in(self):
        for trusted, sandbox in ((False, "1"), (True, ""), (False, "")):
            with self.subTest(trusted=trusted, sandbox=sandbox):
                self.args.trusted_local_assets = trusted
                self.args.out = self.root / f"out-{trusted}-{sandbox}"
                self.environments.clear()
                with (
                    patch.object(exporter.sys, "platform", "linux"),
                    patch.dict(
                        os.environ, {"CHROME_NO_SANDBOX": sandbox, "MARP_USER": ""}
                    ),
                ):
                    original = os.environ.copy()
                    self.do_export()
                self.assertTrue(self.environments)
                for env in self.environments:
                    self.assertEqual(env, original)

    def test_unreviewed_html_layouts_fail_instead_of_printing_tags(self):
        self.deck.write_text('<div class="columns">Layout</div>')
        with self.assertRaisesRegex(exporter.ExportError, "--trusted-local-assets"):
            self.do_export()
        self.assertFalse(self.args.out.exists())

    def test_trusted_layouts_enable_html_but_reject_scripts(self):
        self.args.trusted_local_assets = True
        self.deck.write_text('<div class="columns">Layout</div>')
        self.do_export()
        self.assertTrue(any("--html=true" in call for call in self.calls))
        self.args.out = self.root / "scripts-out"
        self.deck.write_text('<script src="https://example.test/a.js"></script>')
        with self.assertRaises(exporter.ExportError):
            self.do_export()
        self.assertFalse(self.args.out.exists())

    def test_failure_leaves_no_partial_output(self):
        self.fail_pdf = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.do_export()
        self.assertFalse(self.args.out.exists())

    def test_remote_asset_fails_before_browser_runs(self):
        self.remote = True
        with self.assertRaises(exporter.ExportError):
            self.do_export()
        self.assertFalse(any("--pdf" in call for call in self.calls))
        self.assertFalse(self.args.out.exists())

    def test_existing_output_is_not_overwritten(self):
        self.args.out.mkdir()
        sentinel = self.args.out / "keep.txt"
        sentinel.write_text("keep")
        with self.assertRaises(exporter.ExportError):
            self.do_export()
        self.assertEqual(sentinel.read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
