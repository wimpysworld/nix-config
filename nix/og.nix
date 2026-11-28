# Managed by Tailor: nix/og.nix
{ pkgs, ... }:
let
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  system = pkgs.stdenv.hostPlatform.system;
  supported =
    pkgs.lib.elem system supportedSystems && (pkgs.playwright-driver or { }) ? browsers-chromium;
  # The variable Fira Code font reports the family "Fira Code Light".
  staticFiraCode = pkgs.fira-code.override { useVariableFont = false; };
  fontsConf = pkgs.makeFontsConf {
    fontDirectories = [
      pkgs.work-sans
      staticFiraCode
    ];
  };
  ogScript = pkgs.writeTextFile {
    name = "tailor-og-unwrapped";
    destination = "/bin/tailor-og";
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      import argparse
      import base64
      import glob
      import html
      import mimetypes
      import os
      from pathlib import Path
      import re
      import shutil
      import struct
      import subprocess
      import sys
      import tempfile

      WIDTH = 1280
      HEIGHT = 640
      MAX_BYTES = 1048576
      PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
      HEX_COLOR_RE = re.compile(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")
      EXTERNAL_IMPORT_RE = re.compile(
          r"""@import\s+(?:url\(\s*)?["']?https?://[^;"'\)]+["']?\s*\)?[^;]*;""",
          re.IGNORECASE,
      )
      FONT_FACE_RE = re.compile(r"@font-face\s*\{[^}]*\}", re.IGNORECASE | re.DOTALL)
      EXTERNAL_URL_RE = re.compile(r"""url\(\s*["']?https?://""", re.IGNORECASE)

      MUCSS_BASE_CSS = """
      :where(:root, [data-theme="light"]) {
        --mu-background-color: #ffffff;
        --mu-card-background-color: var(--mu-background-color);
        --mu-code-background-color: #f3f5f7;
        --mu-color: #373c44;
        --mu-h1-color: #2d3138;
        --mu-muted-color: #646b79;
        --mu-muted-border-color: #e7eaf0;
        --mu-primary: #0172ad;
        --mu-primary-background: #0172ad;
        --mu-font-family-sans-serif: "Work Sans", system-ui, -apple-system, sans-serif;
        --mu-font-family-monospace: "Fira Code", ui-monospace, monospace;
      }

      :where([data-theme="dark"]) {
        --mu-background-color: #13171f;
        --mu-card-background-color: #181c25;
        --mu-code-background-color: #1a1f28;
        --mu-color: #c2c7d0;
        --mu-h1-color: #f0f1f3;
        --mu-muted-color: #7b8495;
        --mu-muted-border-color: #202632;
        --mu-primary: #01aaff;
        --mu-primary-background: #0172ad;
        --mu-font-family-sans-serif: "Work Sans", system-ui, -apple-system, sans-serif;
        --mu-font-family-monospace: "Fira Code", ui-monospace, monospace;
      }
      """

      OG_LAYOUT_CSS = """
      *,
      *::before,
      *::after {
        box-sizing: border-box;
      }

      html,
      body {
        width: 1280px;
        height: 640px;
        margin: 0;
        padding: 0;
        overflow: hidden;
        background: var(--mu-background-color);
        color: var(--mu-color);
        font-family: var(--mu-font-family-sans-serif);
        -webkit-font-smoothing: antialiased;
        text-rendering: optimizeLegibility;
      }

      .og-canvas {
        position: relative;
        width: 1280px;
        height: 640px;
        padding: 60px 80px;
        overflow: hidden;
        background:
          radial-gradient(
            780px 460px at 82% 24%,
            color-mix(in srgb, var(--mu-primary) 14%, transparent),
            transparent 70%
          ),
          radial-gradient(
            620px 380px at 14% 88%,
            color-mix(in srgb, var(--mu-primary) 8%, transparent),
            transparent 72%
          ),
          var(--mu-background-color);
      }

      .og-safe {
        position: relative;
        z-index: 1;
        width: 1120px;
        height: 520px;
      }

      .og-centered {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: space-between;
        text-align: center;
        padding: 12px 24px 4px;
      }

      .og-centered-main {
        display: flex;
        flex: 1 1 auto;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 20px;
        max-width: 960px;
      }

      .og-icon {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: contain;
      }

      .og-title {
        margin: 0;
        color: var(--mu-h1-color);
        font-family: var(--mu-font-family-sans-serif);
        font-size: 70px;
        font-weight: 800;
        line-height: 1.04;
        letter-spacing: -0.03em;
        max-width: 100%;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .og-title--long {
        font-size: 64px;
      }

      .og-accent-bar {
        width: 84px;
        height: 5px;
        border-radius: 999px;
        background: var(--mu-primary);
      }

      .og-tagline {
        margin: 0;
        color: var(--mu-color);
        font-family: var(--mu-font-family-sans-serif);
        font-size: 27px;
        font-weight: 400;
        line-height: 1.42;
        max-width: 840px;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }

      .og-footer {
        display: flex;
        align-items: center;
        justify-content: center;
        flex-wrap: wrap;
        gap: 14px;
        margin: 0;
        padding-top: 16px;
        color: var(--mu-muted-color);
        font-family: var(--mu-font-family-monospace);
        font-size: 17px;
        font-weight: 500;
        letter-spacing: -0.01em;
      }

      .og-footer-sep {
        color: var(--mu-primary);
        opacity: 0.75;
      }

      /* Split layouts (icon showcase and product-proof preview) */
      .og-split {
        display: flex;
        align-items: stretch;
        gap: 44px;
      }

      .og-split-brand {
        flex: 0 0 42%;
        min-width: 0;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        padding: 26px 0 22px;
      }

      .og-split-brand-top {
        flex: 0 0 auto;
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 15px;
      }

      .og-split--icon .og-split-brand-top {
        margin: auto 0;
        gap: 18px;
      }

      .og-split .og-title {
        font-size: 56px;
        line-height: 1.05;
        white-space: normal;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
      }

      .og-split .og-title--long {
        font-size: 44px;
      }

      .og-split .og-accent-bar {
        width: 64px;
        height: 4px;
      }

      .og-split .og-tagline {
        font-size: 21.5px;
        line-height: 1.42;
        text-align: left;
        max-width: none;
        -webkit-line-clamp: 3;
      }

      .og-split-logo-slot {
        flex: 1 1 0;
        min-height: 0;
        align-self: center;
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 12px 0;
      }

      .og-split-logo {
        position: relative;
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
        min-width: 0;
        min-height: 0;
        max-width: 176px;
        max-height: 176px;
        aspect-ratio: 1 / 1;
      }

      .og-split-logo::before {
        content: "";
        position: absolute;
        inset: -72px;
        background: radial-gradient(
          circle closest-side at 50% 50%,
          color-mix(in srgb, var(--mu-primary) 26%, transparent),
          color-mix(in srgb, var(--mu-primary) 12%, transparent) 46%,
          color-mix(in srgb, var(--mu-primary) 4%, transparent) 74%,
          transparent 100%
        );
        pointer-events: none;
      }

      .og-split-logo .og-icon {
        position: relative;
        z-index: 1;
        filter:
          drop-shadow(0 16px 30px color-mix(in srgb, #000000 34%, transparent))
          drop-shadow(0 0 28px color-mix(in srgb, var(--mu-primary) 20%, transparent));
      }

      .og-split .og-footer {
        flex: 0 0 auto;
        justify-content: flex-start;
        padding-top: 0;
        font-size: 15px;
        gap: 10px;
      }

      .og-split-preview {
        position: relative;
        flex: 1 1 58%;
        min-width: 0;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .og-preview-glow {
        position: absolute;
        inset: -24px;
        background: radial-gradient(
          circle at 55% 48%,
          color-mix(in srgb, var(--mu-primary) 24%, transparent),
          transparent 68%
        );
        pointer-events: none;
      }

      .og-emblem-glow {
        position: absolute;
        inset: -48px;
        background: radial-gradient(
          circle closest-side at 50% 50%,
          color-mix(in srgb, var(--mu-primary) 28%, transparent),
          color-mix(in srgb, var(--mu-primary) 13%, transparent) 46%,
          color-mix(in srgb, var(--mu-primary) 4%, transparent) 74%,
          transparent 100%
        );
        pointer-events: none;
      }

      .og-emblem {
        position: relative;
        z-index: 1;
        width: 312px;
        height: 312px;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .og-emblem .og-icon {
        filter:
          drop-shadow(0 24px 48px color-mix(in srgb, #000000 38%, transparent))
          drop-shadow(0 0 42px color-mix(in srgb, var(--mu-primary) 24%, transparent));
      }

      .og-window {
        position: relative;
        z-index: 1;
        width: 100%;
        height: 468px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        border-radius: 16px;
        border: 1px solid var(--mu-muted-border-color);
        background: var(--mu-code-background-color);
        box-shadow:
          0 24px 60px color-mix(in srgb, #000000 38%, transparent),
          0 0 0 1px color-mix(in srgb, var(--mu-primary) 16%, transparent);
      }

      :root[data-theme="light"] .og-window {
        box-shadow:
          0 20px 48px color-mix(in srgb, #000000 12%, transparent),
          0 0 0 1px color-mix(in srgb, var(--mu-primary) 14%, transparent);
      }

      :root[data-theme="light"] .og-split-logo .og-icon {
        filter:
          drop-shadow(0 12px 24px color-mix(in srgb, #000000 14%, transparent))
          drop-shadow(0 0 24px color-mix(in srgb, var(--mu-primary) 14%, transparent));
      }

      :root[data-theme="light"] .og-emblem .og-icon {
        filter:
          drop-shadow(0 18px 36px color-mix(in srgb, #000000 16%, transparent))
          drop-shadow(0 0 32px color-mix(in srgb, var(--mu-primary) 16%, transparent));
      }

      .og-window-bar {
        flex: 0 0 38px;
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 0 16px;
        border-bottom: 1px solid var(--mu-muted-border-color);
        background: var(--mu-card-background-color);
      }

      .og-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: var(--mu-muted-border-color);
      }

      .og-dot--accent {
        background: color-mix(in srgb, var(--mu-primary) 72%, var(--mu-muted-border-color));
      }

      .og-window-title {
        margin-left: 8px;
        color: var(--mu-muted-color);
        font-family: var(--mu-font-family-monospace);
        font-size: 13px;
        font-weight: 500;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .og-window-body {
        flex: 1 1 auto;
        min-height: 0;
        overflow: hidden;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--mu-code-background-color);
      }

      .og-screenshot {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: contain;
        object-position: center;
        background: var(--mu-code-background-color);
      }

      .og-terminal {
        margin: 0;
        padding: 24px 26px;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: var(--mu-code-background-color);
        color: var(--mu-color);
        font-family: var(--mu-font-family-monospace);
        font-size: 15.5px;
        line-height: 1.7;
        white-space: pre-wrap;
        word-break: break-word;
      }

      .og-term-line {
        display: block;
      }

      .og-term-prompt {
        color: var(--mu-primary);
        font-weight: 600;
      }

      .og-term-cmd {
        color: var(--mu-h1-color);
        font-weight: 500;
      }

      .og-term-comment {
        color: var(--mu-muted-color);
      }
      """


      def fail(message: str) -> None:
          print(f"Error: {message}", file=sys.stderr)
          sys.exit(1)


      def find_chromium() -> str:
          browsers_dir = os.environ.get("TAILOR_OG_BROWSERS_DIR", "")
          if not browsers_dir:
              fail("TAILOR_OG_BROWSERS_DIR is not set.")
          patterns = [
              "chromium-*/chrome-linux64/chrome",
              "chromium-*/chrome-linux/chrome",
              "chromium-*/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
              "chromium-*/chrome-mac/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
              "chromium-*/chrome-mac-arm64/Chromium.app/Contents/MacOS/Chromium",
              "chromium-*/chrome-mac/Chromium.app/Contents/MacOS/Chromium",
          ]
          for pattern in patterns:
              for candidate in sorted(glob.glob(os.path.join(browsers_dir, pattern))):
                  if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                      return candidate
          for candidate in sorted(
              glob.glob(
                  os.path.join(browsers_dir, "chromium-*", "chrome-mac*", "**", "Contents", "MacOS", "*"),
                  recursive=True,
              )
          ):
              if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                  return candidate
          fail(f"Could not locate Chromium executable inside {browsers_dir}.")


      def sanitize_project_css(raw: str) -> str:
          cleaned = EXTERNAL_IMPORT_RE.sub("", raw)

          def strip_external_font_face(match: re.Match[str]) -> str:
              block = match.group(0)
              if EXTERNAL_URL_RE.search(block):
                  return ""
              return block

          return FONT_FACE_RE.sub(strip_external_font_face, cleaned)


      def local_darwin_font_css() -> str:
          if sys.platform != "darwin":
              return ""
          rules = []
          font_specs = [
              ("Work Sans", os.environ.get("TAILOR_OG_WORK_SANS_DIR", "")),
              ("Fira Code", os.environ.get("TAILOR_OG_FIRA_CODE_DIR", "")),
          ]
          weight_tokens = [
              ("extralight", "200"),
              ("extrabold", "800"),
              ("semibold", "600"),
              ("thin", "100"),
              ("light", "300"),
              ("regular", "400"),
              ("retina", "450"),
              ("medium", "500"),
              ("bold", "700"),
              ("black", "900"),
          ]
          for family, font_dir in font_specs:
              if not font_dir or not os.path.isdir(font_dir):
                  continue
              for path in sorted(Path(font_dir).rglob("*")):
                  suffix = path.suffix.lower()
                  if suffix not in (".ttf", ".otf", ".woff2"):
                      continue
                  lower = path.stem.lower()
                  style = "italic" if "italic" in lower else "normal"
                  weight = "100 900" if ("variable" in lower or "vf" in lower or "[wght]" in lower) else "400"
                  for token, val in weight_tokens:
                      if token in lower:
                          weight = val
                          break
                  fmt = {".ttf": "truetype", ".otf": "opentype", ".woff2": "woff2"}[suffix]
                  rules.append(
                      f'@font-face {{ font-family: "{family}"; font-style: {style}; '
                      f'font-weight: {weight}; src: url("{path.resolve().as_uri()}") format("{fmt}"); }}'
                  )
          return "\n".join(rules)


      def to_data_uri(file_path: Path) -> str:
          mime, _ = mimetypes.guess_type(str(file_path))
          if file_path.suffix.lower() == ".svg":
              mime = "image/svg+xml"
          elif file_path.suffix.lower() == ".webp":
              mime = "image/webp"
          elif file_path.suffix.lower() == ".avif":
              mime = "image/avif"
          elif not mime:
              mime = "application/octet-stream"
          encoded = base64.b64encode(file_path.read_bytes()).decode("ascii")
          return f"data:{mime};base64,{encoded}"


      def format_terminal_lines(lines: list[str]) -> str:
          rendered = []
          for raw in lines[:8]:
              line = raw.rstrip("\r\n")
              stripped = line.lstrip()
              if stripped.startswith("#"):
                  rendered.append(f'<span class="og-term-line og-term-comment">{html.escape(line)}</span>')
              elif stripped.startswith("$ "):
                  prefix_len = len(line) - len(stripped)
                  prefix = html.escape(line[:prefix_len])
                  cmd = html.escape(stripped[2:])
                  rendered.append(
                      f'<span class="og-term-line">{prefix}<span class="og-term-prompt">$</span> '
                      f'<span class="og-term-cmd">{cmd}</span></span>'
                  )
              else:
                  rendered.append(f'<span class="og-term-line">{html.escape(line)}</span>')
          return "\n".join(rendered)


      def project_title(repo: str) -> str:
          name = repo.strip()
          if "/" in name:
              name = name.split("/", 1)[1].strip()
          if not name:
              return ""
          parts = name.split("-")
          if any(len(part) <= 2 for part in parts):
              return name
          return " ".join(part[:1].upper() + part[1:] for part in parts)


      def validate_hex(flag: str, value: str) -> str:
          trimmed = value.strip()
          if not HEX_COLOR_RE.match(trimmed):
              fail(f"{flag} must be a 3- or 6-digit hex colour such as #01aaff (got {value!r}).")
          return trimmed


      def validate_png(png_path: Path) -> int:
          if not png_path.is_file():
              fail(f"Rendered PNG was not created at {png_path}.")
          data = png_path.read_bytes()
          size = len(data)
          if size < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
              fail(f"Output is not a valid PNG file ({size} bytes).")
          width, height = struct.unpack(">II", data[16:24])
          if width != WIDTH or height != HEIGHT:
              fail(f"Expected {WIDTH}x{HEIGHT} PNG, got {width}x{height}.")
          if size >= MAX_BYTES:
              fail(f"Rendered PNG is {size} bytes, exceeding the {MAX_BYTES}-byte (1 MB) limit.")
          return size


      def build_html(
          theme: str,
          project_css: str,
          accent: str,
          background: str,
          title: str,
          tagline: str,
          footer: str,
          platforms: str,
          icon_uri: str,
          preview_image_uri: str,
          terminal_lines: list[str],
      ) -> str:
          overrides = []
          if accent:
              overrides.append(f"--mu-primary: {accent};")
              overrides.append(f"--mu-primary-background: {accent};")
          if background:
              overrides.append(f"--mu-background-color: {background};")
          override_css = ""
          if overrides:
              override_css = ":root[data-theme] {\n  " + "\n  ".join(overrides) + "\n}\n"

          title_class = "og-title og-title--long" if len(title) > 16 else "og-title"
          title_html = f'<h1 class="{title_class}">{html.escape(title)}</h1>'
          tagline_html = f'<p class="og-tagline">{html.escape(tagline)}</p>' if tagline else ""

          footer_parts = []
          if footer:
              footer_parts.append(f"<span>{html.escape(footer)}</span>")
          if platforms:
              footer_parts.append(f"<span>{html.escape(platforms)}</span>")
          footer_html = (
              '<p class="og-footer">'
              + '<span class="og-footer-sep" aria-hidden="true">&bull;</span>'.join(footer_parts)
              + "</p>"
              if footer_parts
              else ""
          )

          has_preview = bool(preview_image_uri or terminal_lines)
          if has_preview:
              if preview_image_uri:
                  bar_title = html.escape(title)
                  window_body = f'<img class="og-screenshot" src="{preview_image_uri}" alt="">'
              else:
                  bar_title = html.escape(title.lower().replace(" ", "-")) + " — terminal"
                  window_body = f'<pre class="og-terminal">{format_terminal_lines(terminal_lines)}</pre>'
              split_logo_html = (
                  f"""
                  <div class="og-split-logo-slot">
                    <div class="og-split-logo">
                      <img class="og-icon" src="{icon_uri}" alt="">
                    </div>
                  </div>
                  """
                  if icon_uri
                  else ""
              )
              safe_html = f"""
              <div class="og-safe og-split og-split--preview">
                <div class="og-split-brand">
                  <div class="og-split-brand-top">
                    {title_html}
                    <div class="og-accent-bar" aria-hidden="true"></div>
                    {tagline_html}
                  </div>
                  {split_logo_html}
                  {footer_html}
                </div>
                <div class="og-split-preview">
                  <div class="og-preview-glow" aria-hidden="true"></div>
                  <div class="og-window">
                    <div class="og-window-bar">
                      <span class="og-dot og-dot--accent"></span>
                      <span class="og-dot"></span>
                      <span class="og-dot"></span>
                      <span class="og-window-title">{bar_title}</span>
                    </div>
                    <div class="og-window-body">
                      {window_body}
                    </div>
                  </div>
                </div>
              </div>
              """
          elif icon_uri:
              safe_html = f"""
              <div class="og-safe og-split og-split--icon">
                <div class="og-split-brand">
                  <div class="og-split-brand-top">
                    {title_html}
                    <div class="og-accent-bar" aria-hidden="true"></div>
                    {tagline_html}
                  </div>
                  {footer_html}
                </div>
                <div class="og-split-preview">
                  <div class="og-emblem-glow" aria-hidden="true"></div>
                  <div class="og-emblem">
                    <img class="og-icon" src="{icon_uri}" alt="">
                  </div>
                </div>
              </div>
              """
          else:
              safe_html = f"""
              <div class="og-safe og-centered">
                <div class="og-centered-main">
                  {title_html}
                  <div class="og-accent-bar" aria-hidden="true"></div>
                  {tagline_html}
                </div>
                {footer_html}
              </div>
              """

          darwin_fonts = local_darwin_font_css()
          return f"""<!doctype html>
      <html lang="en" data-theme="{html.escape(theme)}" style="color-scheme: {html.escape(theme)}">
      <head>
      <meta charset="utf-8">
      <style>
      {darwin_fonts}
      {MUCSS_BASE_CSS}
      </style>
      <style>
      {project_css}
      </style>
      <style>
      {override_css}
      {OG_LAYOUT_CSS}
      </style>
      </head>
      <body>
        <main class="og-canvas">
          {safe_html}
        </main>
      </body>
      </html>
      """


      def parse_args() -> argparse.Namespace:
          parser = argparse.ArgumentParser(
              prog="tailor-og",
              description="Generate a 1280x640 offline Open Graph preview image.",
          )
          parser.add_argument("--output", default="pages/og.png", help="Output PNG path (default: pages/og.png)")
          parser.add_argument("--force", action="store_true", help="Overwrite an existing output file")
          parser.add_argument("--theme", choices=["dark", "light"], default="dark", help="Card theme (default: dark)")
          parser.add_argument("--style-css", default="", help="Path to project style.css (default: pages/style.css if present)")
          parser.add_argument("--accent", default="", help="Accent hex colour override (for example #01aaff)")
          parser.add_argument("--background", default="", help="Background hex colour override (for example #13171f)")
          parser.add_argument("--title", default="", help="Project title")
          parser.add_argument("--tagline", default="", help="Short project tagline")
          parser.add_argument("--footer", default="", help="Footer URL or label")
          parser.add_argument("--platforms", default="", help="Supported platforms summary")
          parser.add_argument("--icon", default="", help="Icon path (auto-checks pages/icon.svg then pages/icon.png)")
          parser.add_argument("--include-preview", action="store_true", help="Use split layout with screenshot or terminal preview")
          parser.add_argument("--image", default="", help="Preview screenshot path (falls back to pages/demo-still.png)")
          parser.add_argument("--terminal-line", action="append", default=[], help="Terminal preview line (repeatable)")
          return parser.parse_args()


      def main() -> None:
          args = parse_args()
          output_path = Path(args.output)
          if (output_path.exists() or output_path.is_symlink()) and not args.force:
              fail(
                  f"{output_path} already exists. Refusing to overwrite existing artwork without --force."
              )

          accent = validate_hex("--accent", args.accent) if args.accent.strip() else ""
          background = validate_hex("--background", args.background) if args.background.strip() else ""

          project_css = ""
          if args.style_css:
              style_path = Path(args.style_css)
              if not style_path.is_file():
                  fail(f"Stylesheet not found: {style_path}")
              project_css = sanitize_project_css(style_path.read_text(encoding="utf-8"))
          else:
              default_css = Path("pages/style.css")
              if default_css.is_file():
                  project_css = sanitize_project_css(default_css.read_text(encoding="utf-8"))

          icon_uri = ""
          if args.icon:
              icon_path = Path(args.icon)
              if not icon_path.is_file():
                  fail(f"Icon file not found: {icon_path}")
              icon_uri = to_data_uri(icon_path)
          else:
              for candidate in (Path("pages/icon.svg"), Path("pages/icon.png")):
                  if candidate.is_file():
                      icon_uri = to_data_uri(candidate)
                      break

          preview_image_uri = ""
          terminal_lines: list[str] = []
          if args.include_preview:
              if args.image:
                  image_path = Path(args.image)
                  if not image_path.is_file():
                      fail(f"Preview image not found: {image_path}")
                  preview_image_uri = to_data_uri(image_path)
              else:
                  default_image = Path("pages/demo-still.png")
                  if default_image.is_file():
                      preview_image_uri = to_data_uri(default_image)
                  elif args.terminal_line:
                      terminal_lines = list(args.terminal_line)

          title = project_title(args.title.strip() or Path.cwd().name)
          tagline = args.tagline.strip()
          footer = args.footer.strip()
          platforms = args.platforms.strip()

          chromium = find_chromium()
          oxipng = os.environ.get("TAILOR_OG_OXIPNG") or shutil.which("oxipng")
          if not oxipng:
              fail("oxipng executable is not available.")

          html_doc = build_html(
              theme=args.theme,
              project_css=project_css,
              accent=accent,
              background=background,
              title=title,
              tagline=tagline,
              footer=footer,
              platforms=platforms,
              icon_uri=icon_uri,
              preview_image_uri=preview_image_uri,
              terminal_lines=terminal_lines,
          )

          with tempfile.TemporaryDirectory(prefix="tailor-og-") as tmp_dir:
              tmp = Path(tmp_dir)
              html_path = tmp / "card.html"
              raw_png = tmp / "og.png"
              profile_dir = tmp / "profile"
              html_path.write_text(html_doc, encoding="utf-8")

              cmd = [
                  chromium,
                  "--headless=new",
                  "--disable-gpu",
                  "--no-sandbox",
                  "--disable-dev-shm-usage",
                  "--hide-scrollbars",
                  f"--window-size={WIDTH},{HEIGHT}",
                  "--force-device-scale-factor=1",
                  f"--user-data-dir={profile_dir}",
                  f"--screenshot={raw_png}",
                  html_path.resolve().as_uri(),
              ]
              result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
              if result.returncode != 0:
                  detail = (result.stderr or result.stdout).strip()
                  fail(f"Chromium failed with exit code {result.returncode}: {detail}")

              if not raw_png.is_file():
                  fail("Chromium did not write the screenshot file.")

              opt = subprocess.run(
                  [oxipng, "-q", "-o", "4", "--strip", "safe", str(raw_png)],
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
                  text=True,
              )
              if opt.returncode != 0:
                  detail = (opt.stderr or opt.stdout).strip()
                  fail(f"oxipng failed with exit code {opt.returncode}: {detail}")

              final_size = validate_png(raw_png)

              output_path.parent.mkdir(parents=True, exist_ok=True)
              staged_fd, staged_name = tempfile.mkstemp(prefix=".tailor-og-", suffix=".png", dir=str(output_path.parent))
              os.close(staged_fd)
              staged_path = Path(staged_name)
              try:
                  shutil.copyfile(raw_png, staged_path)
                  os.chmod(staged_path, 0o644)
                  os.replace(staged_path, output_path)
              except BaseException:
                  staged_path.unlink(missing_ok=True)
                  raise

          print(f"Generated {output_path} ({WIDTH}x{HEIGHT}, {final_size} bytes)")
          print(f"Upload {output_path} under GitHub Settings > General > Social preview")


      if __name__ == "__main__":
          main()
    '';
  };
  tailor-og = pkgs.symlinkJoin {
    name = "tailor-og";
    paths = [ ogScript ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/tailor-og" \
        --set FONTCONFIG_FILE "${fontsConf}" \
        --set TAILOR_OG_BROWSERS_DIR "${pkgs.playwright-driver.browsers-chromium}" \
        --set TAILOR_OG_OXIPNG "${pkgs.oxipng}/bin/oxipng" \
        --set TAILOR_OG_WORK_SANS_DIR "${pkgs.work-sans}/share/fonts" \
        --set TAILOR_OG_FIRA_CODE_DIR "${staticFiraCode}/share/fonts" \
        --prefix PATH : "${
          pkgs.lib.makeBinPath [
            pkgs.oxipng
            pkgs.python3
          ]
        }"
    '';
    meta = {
      description = "Offline Open Graph social preview generator";
      mainProgram = "tailor-og";
      platforms = supportedSystems;
    };
  };
in
pkgs.lib.optionals supported [ tailor-og ]
