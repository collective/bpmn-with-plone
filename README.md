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

3. Start a process. `docs/src/diagrams/ping.bpmn` is already deployed to Operaton,
   and starts on a message named `plone`. Send it from a terminal, and find
   the new *Demo* instance waiting in Cockpit:

   ```sh
   curl -X POST -H 'Content-Type: application/json' \
     -d '{"messageName": "plone"}' http://localhost:8800/engine-rest/message
   ```

4. Run the external task worker, to serve service tasks from
   [`tasks/tasks.py`](tasks/tasks.py). It stays in the
   foreground; stop it with Ctrl-C:

   ```sh
   make tasks
   ```

   The environment points it at Operaton with `ENGINE_REST_BASE_URL`, so the
   [operaton-tasks](https://pypi.org/project/operaton-tasks/) command also
   works as `operaton-tasks serve tasks/tasks.py` inside `make shell`.

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
only add-on. It is ephemeral and git-ignored (`site/`); change its
name or feature flags in
[`cookieplone-answers.json`](cookieplone-answers.json), then run
`make clean install`. The services are managed with
[devenv](https://devenv.sh/), configured in [`devenv.nix`](devenv.nix).

### Managing the services

Run these in the repository root. They work wherever devenv is installed, not
only in Codespaces:

```sh
make install     # build the environment, generate and install Plone (once)
make start       # start Operaton, Plone and the proxy in the background
make attach      # follow status and logs of the services (Ctrl-C leaves them running)
make tasks       # run the operaton-tasks worker
make stop        # stop the services
make clean       # remove the generated Plone project and local state
```

## Documentation

The documentation on using BPMN with Plone lives in [`docs/`](docs), as Sphinx
sources in [`docs/src`](docs/src). See [`docs/README.md`](docs/README.md) for
how to build and preview it.
