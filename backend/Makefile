# Playground for BPMN with Plone: Operaton, an ephemeral Plone site generated
# with cookieplone (collective.webhook as its only add-on), a proxy in front of
# Plone, and an operaton-tasks worker.
#
#   make install    build the devenv shell, generate the Plone project,
#                   install it and create the Plone site
#   make start      start everything in the background (devenv up -d)
#   make attach     follow process status and logs (Ctrl-C leaves them running)
#   make stop       stop everything
#   make shell      enter the devenv shell
#
# Plone is at http://localhost:8000 (login admin / admin), Cockpit at
# http://localhost:8800/operaton/app/cockpit/. In Codespaces, use the forwarded
# ports 8000 and 8800. To start from scratch: make clean install
#
# The plone-* targets need the devenv shell (uv and git) and are run by the
# targets above; project name, package name and feature flags live in
# cookieplone-answers.json.

ANSWERS ?= cookieplone-answers.json
PROJECT ?= $(shell sed -n 's/^ *"project_slug": *"\(.*\)".*/\1/p' $(ANSWERS))

ADDON_REQUIREMENT ?= collective.webhook>=0.4.0
ADDON_PACKAGE ?= collective.webhook

PORT ?= 8080

COOKIEPLONE ?= uvx cookieplone
BACKEND := $(PROJECT)/backend

.DEFAULT_GOAL := help

.PHONY: help
help: ## This help message
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

## Run from Codespaces or a terminal with devenv

.PHONY: install
install: ## Build the devenv shell and install Plone with its site
	devenv shell -- $(MAKE) plone-install

.PHONY: start
start: ## Start Operaton, Plone, the proxy and the task worker
	devenv up -d

.PHONY: attach
attach: ## Follow process status and logs
	devenv processes attach

.PHONY: stop
stop: ## Stop everything started with make start
	devenv processes down

.PHONY: shell
shell: ## Enter the devenv shell
	devenv shell

.PHONY: clean
clean: ## Remove the generated Plone project and local state
	$(RM) -r $(PROJECT) tasks/.venv .devenv

## Run inside the devenv shell

# Cookieplone creates $(PROJECT)/ and initializes git in it.
$(BACKEND)/pyproject.toml: $(ANSWERS)
	$(COOKIEPLONE) project --no-input --answers-file $(ANSWERS)
	@test -f $@ || { echo "cookieplone did not generate $@"; exit 1; }

# Add the add-on to the backend. The ZCML include is explicit because
# collective.webhook only registers a z3c.autoinclude entry point.
# Idempotent, so it is safe to run on an already generated project.
.PHONY: addon
addon: $(BACKEND)/pyproject.toml
	grep -q '"$(ADDON_PACKAGE)' $(BACKEND)/pyproject.toml \
		|| sed -i 's/^\(    "plone.api",\)$$/\1\n    "$(ADDON_REQUIREMENT)",/' $(BACKEND)/pyproject.toml
	grep -q '"$(ADDON_REQUIREMENT)"' $(BACKEND)/pyproject.toml \
		|| { echo "could not add $(ADDON_REQUIREMENT) to $(BACKEND)/pyproject.toml"; exit 1; }
	grep -q '$(ADDON_PACKAGE)' $(BACKEND)/instance.yaml \
		|| sed -i "s/^\( *zcml_package_includes: '.*\)'/\1, $(ADDON_PACKAGE)'/" $(BACKEND)/instance.yaml
	grep -q "zcml_package_includes: '.*, $(ADDON_PACKAGE)'" $(BACKEND)/instance.yaml \
		|| { echo "could not add $(ADDON_PACKAGE) to $(BACKEND)/instance.yaml"; exit 1; }

# Set the port in instance.yaml, which the backend Makefile turns into
# zope.ini (listen = localhost:$(PORT)). The file is only touched when the
# value changes, so the instance config is regenerated only then.
.PHONY: port
port: addon
	@grep -q "^ *wsgi_listen: 'localhost:$(PORT)'$$" $(BACKEND)/instance.yaml \
		|| { sed -i '/^ *wsgi_listen:/d' $(BACKEND)/instance.yaml \
		&& { [ -z "$$(tail -c1 $(BACKEND)/instance.yaml)" ] || echo >> $(BACKEND)/instance.yaml; } \
		&& echo "    wsgi_listen: 'localhost:$(PORT)'" >> $(BACKEND)/instance.yaml; }

# The project's backend-install also creates the Plone site (kept if it exists),
# and the task worker's virtualenv is synced here too, to be ready for start.
.PHONY: plone-install
plone-install: port
	$(MAKE) -C $(PROJECT) backend-install
	UV_PROJECT_ENVIRONMENT=$(CURDIR)/tasks/.venv uv sync --project tasks

.PHONY: plone-serve
plone-serve: plone-install
	$(MAKE) -C $(PROJECT) backend-start
