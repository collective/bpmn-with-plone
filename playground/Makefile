# Bootstrap a Plone backend with cookieplone, with collective.webhook as its
# only add-on, and serve it. Run inside the devenv shell (needs uv and git).
#
#   make            generate the project (if missing), install, create the
#                   Plone site (if missing) and serve it on localhost:8800
#   make PORT=9000  serve on another port (default 8800)
#   make install    the same, without serving
#
# Project name, package name and feature flags live in cookieplone-answers.json.
# Login as admin / admin. To start from scratch: rm -rf blicca && make

ANSWERS ?= cookieplone-answers.json
PROJECT ?= $(shell sed -n 's/^ *"project_slug": *"\(.*\)".*/\1/p' $(ANSWERS))

ADDON_REQUIREMENT ?= collective.webhook>=0.4.0
ADDON_PACKAGE ?= collective.webhook

PORT ?= 8800

COOKIEPLONE ?= uvx cookieplone
BACKEND := $(PROJECT)/backend

.DEFAULT_GOAL := serve

.PHONY: help
help: ## This help message
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

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

# The project's backend-install also creates the Plone site (kept if it exists).
.PHONY: install
install: port ## Generate the project, install Plone and create the site
	$(MAKE) -C $(PROJECT) backend-install

.PHONY: serve
serve: install ## Install, then serve Plone on http://localhost:$(PORT)
	$(MAKE) -C $(PROJECT) backend-start

.PHONY: clean
clean: ## Remove the backend virtualenv and instance config
	$(MAKE) -C $(PROJECT) clean
