"""Sphinx extension for embedding BPMN 2.0 diagrams.

Provides a ``bpmn`` directive that renders a ``.bpmn`` file with the
``bpmn-to-image`` command line tool (https://github.com/datakurre/bpmn-to-image):

.. code-block:: rst

   .. bpmn:: diagrams/order.bpmn
      :mode: interactive
      :height: 320px
      :caption: Order handling

or, in MyST Markdown:

.. code-block:: md

   ```{bpmn} diagrams/order.bpmn
   :mode: svg
   ```

Modes:

``interactive`` (default)
    A live bpmn-js token simulation running in the reader's browser. The large
    viewer bundle is written once into ``_static`` and only loaded on pages
    that have a diagram.
``svg``, ``png``
    A static image.
``gif``, ``apng``, ``webp``
    An animated execution, optionally steered by a ``:scenario:`` TOML file.

Only HTML builders render diagrams; other builders skip them (a caption is kept).
"""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
from pathlib import Path

from docutils import nodes
from docutils.parsers.rst import directives
from sphinx.application import Sphinx
from sphinx.errors import SphinxError
from sphinx.util import logging
from sphinx.util.docutils import SphinxDirective

logger = logging.getLogger(__name__)

STATIC_MODES = ("svg", "png", "gif", "apng", "webp")
MODES = ("interactive", *STATIC_MODES)
ASSET_NAME = "bpmn-viewer"


class bpmn(nodes.General, nodes.Element):
    """Placeholder node; the HTML visitor renders it."""


def _mode(argument: str) -> str:
    return directives.choice(argument, MODES)


def _align(argument: str) -> str:
    return directives.choice(argument, ("left", "center", "right"))


class BpmnDirective(SphinxDirective):
    required_arguments = 1
    final_argument_whitespace = True
    has_content = False
    option_spec = {
        "mode": _mode,
        "width": directives.unchanged,
        "height": directives.unchanged,
        "align": _align,
        "alt": directives.unchanged,
        "caption": directives.unchanged,
        "scenario": directives.uri,
        "name": directives.unchanged,
        "class": directives.class_option,
    }

    def run(self) -> list[nodes.Node]:
        rel, path = self.env.relfn2path(self.arguments[0])
        if not Path(path).is_file():
            raise self.error(f"BPMN file not found: {rel}")
        self.env.note_dependency(rel)

        node = bpmn()
        node["source"] = path
        node["mode"] = self.options.get("mode", self.config.bpmn_default_mode)
        for key in ("width", "height", "align", "alt"):
            node[key] = self.options.get(key)
        node["classes"] += self.options.get("class", [])
        node["docname"] = self.env.docname
        node["index"] = self.env.temp_data.setdefault("bpmn_count", 0)
        self.env.temp_data["bpmn_count"] += 1

        if "scenario" in self.options:
            scenario_rel, scenario = self.env.relfn2path(self.options["scenario"])
            if not Path(scenario).is_file():
                raise self.error(f"BPMN scenario file not found: {scenario_rel}")
            self.env.note_dependency(scenario_rel)
            node["scenario"] = scenario
        if node["mode"] not in STATIC_MODES and "scenario" in node:
            raise self.error(":scenario: only applies to animated modes")

        self.add_name(node)
        caption = self.options.get("caption")
        if not caption:
            return [node]

        figure = nodes.figure()
        figure += node
        figure += nodes.caption(caption, caption)
        if node["align"]:
            figure["align"] = node["align"]
        return [figure]


def _run(app: Sphinx, args: list[str], stdin: str | None = None) -> str:
    cmd = [app.config.bpmn_to_image, *args]
    try:
        result = subprocess.run(
            cmd, input=stdin, capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        raise SphinxError(
            f"{app.config.bpmn_to_image!r} not found; install bpmn-to-image "
            "or set bpmn_to_image in conf.py"
        ) from None
    if result.returncode:
        raise SphinxError(f"{' '.join(cmd)} failed:\n{result.stderr}")
    return result.stdout


def _write_viewer_assets(app: Sphinx) -> None:
    """Write the shared viewer bundle to ``_static``, split into CSS and JS."""
    out = Path(app.outdir) / "_static"
    out.mkdir(parents=True, exist_ok=True)
    assets = _run(app, ["--print-viewer-assets", "-"])
    match = re.fullmatch(
        r"\s*<style>\n(.*?)\n</style>\s*<script>\n(.*)\n</script>\s*", assets, re.S
    )
    if not match:
        raise SphinxError("Unexpected output from bpmn-to-image --print-viewer-assets")
    (out / f"{ASSET_NAME}.css").write_text(match[1], encoding="utf-8")
    (out / f"{ASSET_NAME}.js").write_text(match[2], encoding="utf-8")


def _build_finished(app: Sphinx, exception: Exception | None) -> None:
    if exception is None and app.builder.format == "html":
        _write_viewer_assets(app)


def _html_page_context(app, pagename, templatename, context, doctree):
    # Load the (large) viewer bundle only on pages that embed a live diagram.
    # Done through ``metatags`` rather than ``app.add_css_file`` /
    # ``add_js_file``, which would add it to every page. The script must be
    # blocking (not deferred): the inline init calls run at parse time.
    if doctree is None or not any(n["mode"] == "interactive" for n in doctree.findall(bpmn)):
        return
    pathto = context["pathto"]
    context["metatags"] = context.get("metatags", "") + (
        f'<link rel="stylesheet" href="{pathto(f"_static/{ASSET_NAME}.css", 1)}" />\n'
        f'<script src="{pathto(f"_static/{ASSET_NAME}.js", 1)}"></script>\n'
    )


def _style(node: bpmn) -> str:
    parts = []
    if node["width"]:
        parts.append(f"width:{node['width']}")
    if node["height"]:
        parts.append(f"height:{node['height']}")
    return ";".join(parts)


def visit_bpmn_html(self, node: bpmn) -> None:
    app: Sphinx = self.builder.app
    source = Path(node["source"])
    mode = node["mode"]

    if mode == "interactive":
        node_id = "bpmn-" + hashlib.sha1(
            f"{node['docname']}:{node['index']}".encode()
        ).hexdigest()[:10]
        args = ["--format", "html", "--no-assets", "--id", node_id]
        for key in ("width", "height", "align"):
            if node[key]:
                args += [f"--{key}", node[key]]
        html = _run(app, [*args, str(source), "-"])
        self.body.append(html)
    else:
        args = ["--format", mode]
        if "scenario" in node:
            args += ["--scenario", node["scenario"]]
        # Name output after the inputs so unchanged diagrams are not re-rendered.
        digest = hashlib.sha1()
        for path in (source, node.get("scenario")):
            if path:
                digest.update(Path(path).read_bytes())
        digest.update(" ".join(args).encode())
        name = f"{source.stem}-{digest.hexdigest()[:10]}.{mode}"
        imagedir = Path(self.builder.outdir) / self.builder.imagedir
        target = imagedir / name
        if not target.exists():
            imagedir.mkdir(parents=True, exist_ok=True)
            _run(app, [*args, str(source), str(target)])
        src = f"{self.builder.imgpath}/{name}"
        alt = node["alt"] or source.stem.replace("-", " ").replace("_", " ")
        style = _style(node)
        attrs = f' style="{style}"' if style else ""
        classes = " ".join(["bpmn-image", *node["classes"]])
        self.body.append(f'<img class="{classes}" src="{src}" alt="{alt}"{attrs} />')
    raise nodes.SkipNode


def visit_bpmn_fallback(self, node: bpmn) -> None:
    """Non-HTML builders: a diagram cannot be shown, skip it."""
    raise nodes.SkipNode


def setup(app: Sphinx) -> dict:
    app.add_config_value("bpmn_to_image", shutil.which("bpmn-to-image") or "bpmn-to-image", "env")
    app.add_config_value("bpmn_default_mode", "interactive", "env", [str])
    app.add_node(
        bpmn,
        html=(visit_bpmn_html, None),
        text=(visit_bpmn_fallback, None),
        latex=(visit_bpmn_fallback, None),
        man=(visit_bpmn_fallback, None),
        texinfo=(visit_bpmn_fallback, None),
    )
    app.add_directive("bpmn", BpmnDirective)
    app.connect("html-page-context", _html_page_context)
    app.connect("build-finished", _build_finished)
    return {"version": "0.1", "parallel_read_safe": True, "parallel_write_safe": False}
