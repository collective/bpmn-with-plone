# BPMN with Plone: documentation

The documentation is built with Sphinx and
[plone-sphinx-theme](https://github.com/plone/plone-sphinx-theme).

BPMN diagrams are embedded with the in-repository Sphinx extension
[`src/_ext/sphinx_bpmn.py`](src/_ext/sphinx_bpmn.py), which renders `.bpmn`
files with [bpmn-to-image](https://github.com/datakurre/bpmn-to-image) — as a
live token simulation, or as static/animated images.

## Development

Everything comes from the Nix flake in this directory. In `nix develop` the
usual Sphinx `Makefile` is available; run these here, in `docs/`:

```sh
nix develop                # shell with sphinx, sphinx-autobuild, bpmn-to-image, uv
make watch                 # rebuild on changes and reload the browser (also: make livehtml)
make html                  # build once into build/html
make strict                # build failing on warnings, as CI does
make skills                # install the plone-doc-style agent skill (git-ignored)
make help                  # all targets
```

`make watch` serves on `127.0.0.1:8100`, not to collide with the playground's
proxy on 8000. `make watch HOST=0.0.0.0` serves beyond loopback (e.g. from a
container). Without entering the shell:

```sh
nix run .#serve            # same live-reloading server
nix build .#docs           # build the site into ./result
nix flake check -L         # what CI runs
```

`make skills` clones [plone-doc-style-skill](https://github.com/plone/plone-doc-style-skill)
into `.skills/` at the repository root, and links it into `.agents/skills/`
(read by Codex, opencode and other agents) and `.claude/skills/` (Claude Code)
there. None of it is committed; re-run it to update, or set
`PLONE_DOC_STYLE_REF` to pin a branch or tag.

Python dependencies live in `pyproject.toml` / `uv.lock` here; after changing
them, run `uv lock` inside `nix develop`.

## Publishing

[`.github/workflows/docs.yml`](../.github/workflows/docs.yml) builds the site
with Nix on every push and pull request, and deploys `main` to GitHub Pages (set *Settings → Pages → Source* to
*GitHub Actions* once).
