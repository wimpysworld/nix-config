#!/usr/bin/env python3
"""Export a trusted Marp deck. Browser exports require installed browser tools."""

import argparse
import base64
import html
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, unquote_to_bytes, urlsplit
from xml.parsers import expat

THEME = Path(__file__).absolute().parent.parent / "assets/theme/catppuccin.css"
FORMATS = (
    "html",
    "pdf",
    "pptx",
    "png",
    "jpeg",
    "png-cover",
    "jpeg-cover",
    "notes",
    "pptx-editable",
)
MIME = {
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
}
URL = re.compile(r"url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*))\s*\)", re.I)


class ExportError(ValueError):
    pass


def run(args, **kwargs):
    return subprocess.run(
        args, check=True, text=True, capture_output=True, **kwargs
    ).stdout


def data_uri(data, mime):
    return f"data:{mime};base64,{base64.b64encode(data).decode('ascii')}"


def plain_path(path):
    path = Path(path).expanduser().absolute()
    if any(part.is_symlink() for part in (path, *path.parents)):
        raise ExportError(f"Symlink paths are not accepted: {path}")
    return path.resolve()


class Assets:
    def __init__(self, root, trusted=False):
        self.root = root.resolve()
        self.trusted = trusted
        self.used = {}

    def embed(self, value):
        value = value.strip()
        if not value or value.startswith("#"):
            return value
        if "\\" in value or any(ord(c) < 32 for c in value):
            raise ExportError(f"Invalid asset URL: {value[:160]}")
        url = urlsplit(value)
        if url.scheme == "data":
            header, separator, payload = value.partition(",")
            if not separator:
                raise ExportError("Invalid data URL")
            mime = header[5:].split(";", 1)[0].lower()
            try:
                data = (
                    base64.b64decode(payload, validate=True)
                    if header.endswith(";base64")
                    else unquote_to_bytes(payload)
                )
            except ValueError as exc:
                raise ExportError("Invalid base64 asset") from exc
        else:
            if (
                url.scheme
                or url.netloc
                or url.query
                or Path(unquote(url.path)).is_absolute()
            ):
                raise ExportError(
                    f"Remote or absolute asset URL is not allowed: {value[:160]}"
                )
            if not self.trusted:
                raise ExportError("Local assets require --trusted-local-assets")
            path = plain_path(self.root / unquote(url.path))
            if not path.is_relative_to(self.root):
                raise ExportError(f"Asset escapes the deck directory: {value}")
            if not path.is_file() or path.stat().st_size > 32 * 1024 * 1024:
                raise ExportError(f"Asset is missing or exceeds 32 MiB: {path}")
            mime = MIME.get(path.suffix.lower()) or mimetypes.guess_type(path.name)[0]
            data = path.read_bytes()
            self.used[value] = str(path)
        if mime not in {
            "image/png",
            "image/jpeg",
            "image/gif",
            "image/webp",
            "image/svg+xml",
            *MIME.values(),
        }:
            raise ExportError(f"Unsupported offline asset type: {mime}")
        if mime == "image/svg+xml":
            self.validate_svg(data)
        return data_uri(data, mime) + (f"#{url.fragment}" if url.fragment else "")

    def validate_svg(self, data):
        if len(data) > 32 * 1024 * 1024:
            raise ExportError("SVG exceeds 32 MiB")
        parser = expat.ParserCreate(namespace_separator="}")
        text = []

        def reject_declaration(*_args):
            raise ExportError("SVG DTD and entity declarations are not allowed")

        def start_element(tag, attrs):
            tag = tag.rsplit("}", 1)[-1].lower()
            if tag in {
                "script",
                "foreignobject",
                "image",
                "use",
                "feimage",
                "animate",
                "animatetransform",
                "animatemotion",
                "set",
            }:
                raise ExportError(f"SVG element requires a flattened asset: {tag}")
            for key, value in attrs.items():
                key = key.rsplit("}", 1)[-1].lower()
                if key.startswith("on") or key in {"href", "src"}:
                    raise ExportError(f"SVG attribute is not allowed: {key}")
                self.svg_css(value)

        parser.StartDoctypeDeclHandler = reject_declaration
        parser.EntityDeclHandler = reject_declaration
        parser.ExternalEntityRefHandler = reject_declaration
        parser.ProcessingInstructionHandler = reject_declaration
        parser.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_NEVER)
        parser.StartElementHandler = start_element
        parser.CharacterDataHandler = text.append
        try:
            parser.Parse(data, True)
        except expat.ExpatError as exc:
            raise ExportError("Invalid SVG asset") from exc
        self.svg_css("".join(text))

    def svg_css(self, value):
        value = re.sub(r"/\*.*?\*/", "", value, flags=re.S)
        if re.search(r"url\s*\(", URL.sub("", value), re.I):
            raise ExportError("Malformed SVG asset URL")
        if re.search(r"(?:image-set|src)\s*\(", value, re.I):
            raise ExportError("SVG image-set()/src() references are not supported")
        for match in URL.finditer(value):
            if (
                not next(v for v in match.groups() if v is not None)
                .strip()
                .startswith("#")
            ):
                raise ExportError("SVG assets must not reference other files")
        if "\\" in value or "@import" in value.lower():
            raise ExportError("SVG CSS escapes and imports are not supported")

    def css(self, value):
        def decode(text):
            return re.sub(
                r"\\([0-9a-fA-F]{1,6})\s?|\\([^\n])",
                lambda m: chr(int(m[1], 16)) if m[1] else m[2],
                text,
            )

        # Preserve selector and string escapes. Decode only for auditing and URLs.
        value = re.sub(r"/\*.*?\*/", "", value, flags=re.S)
        if re.search(r"url\s*\(", decode(URL.sub("", value)), re.I):
            raise ExportError("Malformed or escaped CSS asset function")
        if re.search(r"@import\b|(?:image-set|src)\s*\(", decode(value), re.I):
            raise ExportError(
                "CSS imports and image-set()/src() are not supported offline"
            )
        return URL.sub(
            lambda m: (
                'url("'
                + self.embed(
                    decode(next(v for v in m.groups() if v is not None)).strip()
                )
                + '")'
            ),
            value,
        )


class OfflineHTML(HTMLParser):
    def __init__(self, assets):
        super().__init__(convert_charrefs=False)
        self.assets = assets
        self.parts = []
        self.style = False
        self.slides = 0

    def handle_starttag(self, tag, attrs):
        if tag in {
            "base",
            "iframe",
            "object",
            "embed",
            "form",
            "video",
            "audio",
            "source",
            "animate",
            "animatetransform",
            "animatemotion",
            "set",
        }:
            raise ExportError(f"Unsupported offline HTML element: {tag}")
        attrs = dict(attrs)
        if tag == "link" and attrs.get("rel") != "canonical":
            raise ExportError("External HTML links are not supported")
        if tag == "meta" and (attrs.get("http-equiv") or "").lower() == "refresh":
            raise ExportError("HTML refresh is not supported")
        if tag == "section" and "data-size" in attrs and "id" in attrs:
            self.slides += 1
        for key, value in attrs.items():
            if key == "srcset" or key.startswith("on"):
                raise ExportError(f"Unsupported HTML attribute: {key}")
            if value is None:
                continue
            if key in {
                "style",
                "fill",
                "stroke",
                "filter",
                "clip-path",
                "mask",
                "cursor",
            }:
                attrs[key] = self.assets.css(value)
            elif key in {"src", "poster", "xlink:href", "background"} or (
                key == "href" and tag not in {"a", "link"}
            ):
                if tag == "script":
                    raise ExportError("External scripts are not supported")
                attrs[key] = self.assets.embed(value)
            elif key == "href" and urlsplit(value).scheme not in {
                "",
                "https",
                "http",
                "mailto",
            }:
                raise ExportError("Unsafe hyperlink scheme")
        self.parts.append(
            "<"
            + tag
            + "".join(
                " "
                + key
                + ("" if value is None else '="' + html.escape(value, quote=True) + '"')
                for key, value in attrs.items()
            )
            + ">"
        )
        self.style = tag == "style"

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.parts[-1] = self.parts[-1][:-1] + " />"
        self.style = False

    def handle_endtag(self, tag):
        self.parts.append(f"</{tag}>")
        if tag == "style":
            self.style = False

    def handle_data(self, data):
        self.parts.append(self.assets.css(data) if self.style else data)

    def handle_entityref(self, name):
        self.parts.append(f"&{name};")

    def handle_charref(self, name):
        self.parts.append(f"&#{name};")

    def handle_comment(self, data):
        self.parts.append(f"<!--{data}-->")

    def handle_decl(self, decl):
        self.parts.append(f"<!{decl}>")


def font_css():
    rules = []
    for family, styles in (
        (
            "Work Sans",
            (
                ("Regular", 400, "normal"),
                ("Bold", 700, "normal"),
                ("Italic", 400, "italic"),
                ("Bold Italic", 700, "italic"),
            ),
        ),
        (
            "FiraCode Nerd Font Mono",
            (("Regular", 400, "normal"), ("Bold", 700, "normal")),
        ),
    ):
        for style, weight, slant in styles:
            result = run(
                ["fc-match", "-f", "%{family}\n%{file}", f"{family}:style={style}"]
            )
            families, filename = result.split("\n", 1)
            if family not in families.split(","):
                raise ExportError(f"Required font is missing: {family}")
            path = Path(filename)
            if path.suffix.lower() not in MIME:
                raise ExportError(f"Unsupported font format: {path}")
            rules.append(
                f'@font-face{{font-family:"{family}";font-style:{slant};font-weight:{weight};src:url("{data_uri(path.read_bytes(), MIME[path.suffix.lower()])}")}}'
            )
    return "\n".join(rules)


def export(args):
    deck = plain_path(args.input)
    out = plain_path(args.out)
    if not deck.is_file() or deck.suffix.lower() != ".md":
        raise ExportError("--input must be an existing Markdown file")
    if out.exists():
        raise ExportError(
            "--out must be a new directory, to prevent stale or overwritten exports"
        )
    if not THEME.is_file():
        raise ExportError(f"Required theme is missing: {THEME}")
    help_text = run(["marp", "--help"])
    formats = list(args.formats or FORMATS)
    if "--pptx-editable" not in help_text and not args.formats:
        formats.remove("pptx-editable")
        print(
            "Installed Marp CLI does not support experimental editable PPTX.",
            file=sys.stderr,
        )
    for fmt in formats:
        flag = {
            "html": "--theme",
            "png": "--images",
            "jpeg": "--images",
            "png-cover": "--image",
            "jpeg-cover": "--image",
        }.get(fmt, "--" + fmt)
        if flag not in help_text:
            raise ExportError(f"Installed Marp CLI does not support {fmt}")
    browser = None
    if set(formats) - {"html", "notes"}:
        browser = args.browser_path or next(
            (
                shutil.which(name)
                for name in (
                    "chromium",
                    "google-chrome",
                    "brave",
                    "brave-browser",
                    "microsoft-edge",
                    "firefox",
                )
                if shutil.which(name)
            ),
            None,
        )
        if not browser:
            raise ExportError(
                "Browser exports require Chromium, Chrome, Edge, or Firefox. Use --browser-path."
            )
    if "pptx-editable" in formats and not (
        shutil.which("soffice") or shutil.which("libreoffice")
    ):
        raise ExportError(
            "Experimental editable PPTX requires LibreOffice Impress (soffice)"
        )
    source = deck.read_text(encoding="utf-8")
    if re.search(r"<\s*script\b", source, re.I):
        raise ExportError("Scripts in Markdown are not supported")
    if not args.trusted_local_assets and re.search(
        r"<\s*(?:div|span|p|br|figure|section|table|img)\b", source, re.I
    ):
        raise ExportError(
            "HTML layouts require --trusted-local-assets after reviewing the deck"
        )
    fonts = font_css()
    assets = Assets(deck.parent, args.trusted_local_assets)
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="marp-export-", dir=out.parent) as tmp:
        work = Path(tmp)
        env = os.environ.copy()
        if (
            sys.platform == "linux"
            and args.trusted_local_assets
            and env.get("CHROME_NO_SANDBOX")
        ):
            # Marp otherwise moves temporary files to HOME for Snap compatibility.
            # MARP_USER also disables the sandbox, so require the existing opt-in.
            env["MARP_USER"] = "1"
            env["TMPDIR"] = str(work)
        theme = work / "theme.css"
        # Marp resolves built-in theme imports itself, before the HTML asset audit.
        theme.write_text(THEME.read_text() + "\n" + fonts, encoding="utf-8")
        base = [
            "marp",
            "--no-config-file",
            "--html=" + str(args.trusted_local_assets).lower(),
            "--theme",
            str(theme),
        ]
        raw = work / "raw.html"
        run([*base, "--output", str(raw), "--", str(deck)], cwd=work, env=env)
        parser = OfflineHTML(assets)
        parser.feed(raw.read_text(encoding="utf-8"))
        parser.close()
        document = "".join(parser.parts)
        csp = "default-src 'none'; img-src data:; font-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; base-uri 'none'; form-action 'none'"
        document = document.replace(
            "<head>",
            '<head><meta http-equiv="Content-Security-Policy" content="'
            + html.escape(csp, quote=True)
            + '">',
            1,
        )
        results = work / "results"
        results.mkdir()
        if "html" in formats:
            (results / f"{deck.stem}.html").write_text(document, encoding="utf-8")
        if browser:
            base += [
                "--browser",
                "firefox" if "firefox" in Path(browser).name.lower() else "chrome",
                "--browser-path",
                browser,
            ]
        if assets.used:
            base += ["--allow-local-files"]
        for fmt in formats:
            if fmt == "html":
                continue
            suffix = {
                "notes": "txt",
                "pptx-editable": "editable.pptx",
                "png-cover": "cover.png",
                "jpeg-cover": "cover.jpeg",
            }.get(fmt, fmt)
            destination = results / f"{deck.stem}.{suffix}"
            flags = ["--images", fmt] if fmt in {"png", "jpeg"} else ["--" + fmt]
            if fmt == "pptx-editable":
                flags = ["--pptx", "--pptx-editable"]
            elif fmt.endswith("-cover"):
                flags = ["--image", fmt.removesuffix("-cover")]
            log = run(
                [*base, *flags, "--output", str(destination), "--", str(deck)],
                cwd=work,
                env=env,
            )
            generated = (
                [
                    p
                    for p in results.iterdir()
                    if re.fullmatch(re.escape(deck.stem) + r"\.\d+\." + fmt, p.name)
                ]
                if fmt in {"png", "jpeg"}
                else [destination]
            )
            if not generated or any(not p.is_file() for p in generated):
                raise ExportError(f"Marp did not produce {fmt}: {log}")
            if (
                fmt in {"png", "jpeg"}
                and parser.slides
                and len(generated) != parser.slides
            ):
                raise ExportError(
                    f"Expected {parser.slides} slide images, got {len(generated)}"
                )
        (results / "export.json").write_text(
            json.dumps(
                {
                    "marp": run(["marp", "--version"], cwd=work).strip(),
                    "formats": formats,
                    "slides": parser.slides,
                    "editable_pptx": "Experimental. Appearance can differ. Presenter notes are not supported."
                    if "pptx-editable" in formats
                    else None,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        results.rename(out)
    print(f"Exported {', '.join(formats)} to {out}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument(
        "--formats",
        nargs="+",
        choices=FORMATS,
        help="Default: all supported formats, including experimental editable PPTX",
    )
    parser.add_argument(
        "--trusted-local-assets",
        action="store_true",
        help="Enable reviewed HTML and deck-local assets. Never use with untrusted Markdown.",
    )
    parser.add_argument(
        "--browser-path", help="Browser executable for PDF, PPTX, PNG, and JPEG"
    )
    args = parser.parse_args()
    try:
        export(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        detail = (
            exc.stderr if isinstance(exc, subprocess.CalledProcessError) else str(exc)
        )
        parser.exit(1, f"Export failed: {detail}\n")


if __name__ == "__main__":
    main()
