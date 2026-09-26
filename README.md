# BPMN with Plone

Documentation on using BPMN 2.0 business process models with Plone, with a
playground to try it out: [Operaton](https://operaton.org/) as the process
engine and a [Plone](https://plone.org/) site, running in
[GitHub Codespaces](https://codespaces.new/collective/bpmn-with-plone).

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/collective/bpmn-with-plone)

## Getting started

1. Open the repository in Codespaces with the button above. The first start
   builds the environment and generates the Plone site, which takes a few
   minutes. Operaton and Plone then start by themselves, and the forwarded
   port 8000 opens in your browser.

2. Find the services below that address. In Codespaces, it is the URL of
   port 8000 in the *Ports* tab; on your own machine, `http://localhost:8000`.

   | What | Path | Login |
   | ---- | ---- | ----- |
   | Plone | `/` | `admin` / `admin` |
   | Operaton Cockpit | `/operaton/app/cockpit/` | `demo` / `demo` |
   | Operaton Tasklist | `/operaton/app/tasklist/` | `demo` / `demo` |
   | Operaton Admin | `/operaton/app/admin/` | `demo` / `demo` |

3. Start a process. `docs/diagrams/ping.bpmn` is already deployed to Operaton,
   and starts on a message named `plone`. Send it from a terminal, and find
   the new *Demo* instance waiting in Cockpit:

   ```sh
   curl -X POST -H 'Content-Type: application/json' \
     -d '{"messageName": "plone"}' http://localhost:8800/engine-rest/message
   ```

4. Run the external task worker, to serve service tasks from
   [`backend/tasks/tasks.py`](backend/tasks/tasks.py). It stays in the
   foreground; stop it with Ctrl-C:

   ```sh
   make -C backend tasks
   ```

   The environment points it at Operaton with `ENGINE_REST_BASE_URL`, so the
   [operaton-tasks](https://pypi.org/project/operaton-tasks/) command also
   works as `operaton-tasks serve tasks/tasks.py` inside `make -C backend shell`.

The Operaton user is created with a fresh database only, so the `demo` login
does not appear in a database that already has another one.

### How it fits together

Only port 8000 is forwarded. A proxy there serves Plone at `/` and Operaton at
`/operaton`, and makes both create links for the public address, which is
`https` in Codespaces. Behind it, the services reach each other at localhost:

| Port | What | Notes |
| ---- | ---- | ----- |
| 8000 | Proxy ([Caddy](https://caddyserver.com/)) | the only forwarded port |
| 8080 | Plone | `http://localhost:8080/Plone` |
| 8800 | Operaton | Engine REST at `http://localhost:8800/engine-rest` |
| 8081 | Worker health check | only while the worker runs, at `/healthz` |

Plone is generated with [cookieplone](https://github.com/plone/cookieplone),
with [collective.webhook](https://pypi.org/project/collective.webhook/) as its
only add-on. It is ephemeral and git-ignored (`backend/site/`); change its
name or feature flags in
[`backend/cookieplone-answers.json`](backend/cookieplone-answers.json), then run
`make clean install`. The services are managed with
[devenv](https://devenv.sh/), configured in [`backend/`](backend).

### Managing the services

Run these in `backend/` (or as `make -C backend …`). They work wherever
devenv is installed, not only in Codespaces:

```sh
make install     # build the environment, generate and install Plone (once)
make start       # start Operaton, Plone and the proxy in the background
make attach      # follow status and logs of the services (Ctrl-C leaves them running)
make tasks       # run the operaton-tasks worker
make stop        # stop the services
make clean       # remove the generated Plone project and local state
```

## Documentation

The documentation is built with Sphinx and
[plone-sphinx-theme](https://github.com/plone/plone-sphinx-theme).

BPMN diagrams are embedded with the in-repository Sphinx extension
[`docs/_ext/sphinx_bpmn.py`](docs/_ext/sphinx_bpmn.py), which renders `.bpmn`
files with [bpmn-to-image](https://github.com/datakurre/bpmn-to-image) — as a
live token simulation, or as static/animated images.

### Development

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

`make watch HOST=0.0.0.0 PORT=8100` serves beyond loopback (e.g. from a
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

### Publishing

`.github/workflows/docs.yml` builds the site with Nix on every push and pull
request, and deploys `main` to GitHub Pages (set *Settings → Pages → Source* to
*GitHub Actions* once).
