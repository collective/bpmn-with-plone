# BPMN with Plone

Documentation on using BPMN 2.0 business process models with Plone, built with
Sphinx and [plone-sphinx-theme](https://github.com/plone/plone-sphinx-theme).

BPMN diagrams are embedded with the in-repository Sphinx extension
[`docs/_ext/sphinx_bpmn.py`](docs/_ext/sphinx_bpmn.py), which renders `.bpmn`
files with [bpmn-to-image](https://github.com/datakurre/bpmn-to-image) — as a
live token simulation, or as static/animated images.

## Development

Everything comes from the Nix flake. In `nix develop` the usual Sphinx
`Makefile` is available:

```sh
nix develop                # shell with sphinx, sphinx-autobuild, bpmn-to-image, uv
make watch                 # rebuild on changes and reload the browser (also: make livehtml)
make html                  # build once into build/html
make strict                # build failing on warnings, as CI does
make skills                # install the plone-doc-style agent skill (git-ignored)
make help                  # all targets
```

`make watch HOST=0.0.0.0 PORT=8000` serves beyond loopback (e.g. from a
container). Without entering the shell:

```sh
nix run .#serve            # same live-reloading server
nix build .#docs           # build the site into ./result
nix flake check -L         # what CI runs
```

`make skills` clones [plone-doc-style-skill](https://github.com/plone/plone-doc-style-skill)
into `.skills/` and links it into `.agents/skills/` (read by Codex, opencode
and other agents) and `.claude/skills/` (Claude Code). None of it is committed;
re-run it to update, or set `PLONE_DOC_STYLE_REF` to pin a branch or tag.

Python dependencies live in `pyproject.toml` / `uv.lock`; after changing them,
run `uv lock` inside `nix develop`.

## Playground

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/datakurre/bpmn-with-plone)

The repository opens in [GitHub Codespaces](https://codespaces.new/datakurre/bpmn-with-plone)
with a playground for trying BPMN with Plone. The devcontainer runs
[devenv](https://devenv.sh/) from [`backend/`](backend), which starts:

| Port | What |
| ---- | ---- |
| 8000 | Plone, behind a proxy (login `admin` / `admin`); opens automatically |
| 8080 | Plone backend directly |
| 8800 | [Operaton](https://operaton.org/), with Cockpit at `/operaton/app/cockpit/` |

Plone is generated with [cookieplone](https://github.com/plone/cookieplone) on
first start, with [collective.webhook](https://pypi.org/project/collective.webhook/)
as its only add-on. Operaton auto-deploys `docs/diagrams/ping.bpmn`, and an
[operaton-tasks](https://pypi.org/project/operaton-tasks/) worker runs the
handlers in `backend/tasks/tasks.py`. The shell has `ENGINE_REST_BASE_URL`
pointing at Operaton, so `operaton-tasks` finds the engine (its own default is
port 8080, which is Plone here).

Inside `backend/`, the same works outside Codespaces wherever
[devenv](https://devenv.sh/) is installed:

```sh
make install     # build the environment, generate and install Plone (once)
make start       # start Operaton, Plone, the proxy and the task worker
make attach      # follow process status and logs (Ctrl-C leaves them running)
make stop
make clean       # remove the generated Plone project and local state
```

The generated Plone project is ephemeral and git-ignored (`backend/site/`).
Change its name or feature flags in `backend/cookieplone-answers.json`, then
`make clean install`.

## Publishing

`.github/workflows/docs.yml` builds the site with Nix on every push and pull
request, and deploys `main` to GitHub Pages (set *Settings → Pages → Source* to
*GitHub Actions* once).
