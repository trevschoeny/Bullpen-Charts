#!/usr/bin/env python3
"""Build the standalone (GitHub Pages) version from the artifact source.

The artifact platform wraps bullpen-charts.html in its own <html>/<head>/<body>.
A static host does not, so this script wraps the same file — one source, two
targets, no drift. Run it after every change to bullpen-charts.html.
"""
import pathlib, shutil, re, hashlib

HERE = pathlib.Path(__file__).parent
SRC = HERE / "bullpen-charts.html"
DIST = HERE / "dist"

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="description" content="Chart pitching bullpens by team and pitcher: location, pitch type, velocity, intended target, strike rate, command and heat maps.">
<meta name="theme-color" content="#F1F3F0" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0F1412" media="(prefers-color-scheme: dark)">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="Bullpen">
<link rel="manifest" href="manifest.webmanifest">
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.58.0/dist/umd/supabase.min.js"></script>
<script src="config.js"></script>
<link rel="icon" href="icon-192.png" sizes="192x192">
<link rel="apple-touch-icon" href="icon-180.png">
<style>
  :root { color-scheme: light dark; }
  html, body { margin: 0; }
  body { font: 14px system-ui, sans-serif; background: #F1F3F0; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
  /* Safe-area padding so the sticky header clears an iPad notch in standalone mode. */
  .topbar { padding-top: env(safe-area-inset-top, 0px); }
</style>
</head>
<body>
"""

TAIL = """
<script>
// Offline support: bullpens happen at fields with bad signal. Cache-first for
// the shell, so the app opens with no connection at all.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function () { /* non-fatal */ });
  });
}
</script>
</body>
</html>
"""


def main():
    src = SRC.read_text()
    if "<!doctype" in src.lower():
        raise SystemExit("Source already looks like a full document — check bullpen-charts.html")

    DIST.mkdir(exist_ok=True)
    page = HEAD + src + TAIL
    (DIST / "index.html").write_text(page)

    # Cache name must change when the app changes, or browsers serve the old one.
    digest = hashlib.sha256(page.encode()).hexdigest()[:12]
    sw = (HERE / "sw.template.js").read_text().replace("__VERSION__", digest)
    (DIST / "sw.js").write_text(sw)

    for name in ("manifest.webmanifest", "icon-192.png", "icon-512.png",
                 "icon-180.png", "icon-maskable-512.png", "README.md", ".nojekyll",
                 "config.js", "supabase-schema.sql"):
        p = HERE / "static" / name
        if p.exists():
            shutil.copy(p, DIST / name)

    kb = len(page.encode()) / 1024
    print(f"dist/index.html  {kb:.0f} KB  (cache {digest})")
    for f in sorted(DIST.iterdir()):
        print("  ", f.name)


if __name__ == "__main__":
    main()
