# Minimal makefile for Sphinx documentation
#
# Run inside `nix develop`, which provides sphinx, sphinx-autobuild and
# bpmn-to-image.

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SPHINXAUTOBUILD ?= sphinx-autobuild
SOURCEDIR     = docs
BUILDDIR      = build

# Address of the `watch` server; use HOST=0.0.0.0 to reach it from outside
# a container or sandbox.
HOST          ?= 127.0.0.1
PORT          ?= 8000

# Agent skills installed by `make skills`.
SKILLS_DIR    = .skills
PLONE_DOC_STYLE_REPO ?= https://github.com/plone/plone-doc-style-skill
PLONE_DOC_STYLE_REF  ?= main

# Put it first so that "make" without argument is like "make help".
.DEFAULT_GOAL := help

.PHONY: help
help:  ## Show this help
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
	@echo
	@echo "Project targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: watch
watch:  ## Rebuild on changes and reload the browser (HOST, PORT)
	$(SPHINXAUTOBUILD) \
		--host "$(HOST)" --port "$(PORT)" \
		--watch "$(SOURCEDIR)/_ext" \
		--ignore "*.swp" --ignore "*~" \
		"$(SOURCEDIR)" "$(BUILDDIR)/html" $(SPHINXOPTS) $(O)

.PHONY: livehtml
livehtml: watch  ## Alias for watch

.PHONY: strict
strict:  ## Build HTML, failing on warnings (as CI does)
	$(SPHINXBUILD) -W --keep-going -b html "$(SOURCEDIR)" "$(BUILDDIR)/html" $(SPHINXOPTS) $(O)

.PHONY: clean
clean:  ## Remove the build directory
	rm -rf "$(BUILDDIR)"

.PHONY: skills
skills:  ## Install the plone-doc-style agent skill (Claude Code, Codex, opencode, ...), git-ignored
	@if [ -d "$(SKILLS_DIR)/plone-doc-style-skill/.git" ]; then \
		git -C "$(SKILLS_DIR)/plone-doc-style-skill" fetch --quiet --depth 1 origin "$(PLONE_DOC_STYLE_REF)" && \
		git -C "$(SKILLS_DIR)/plone-doc-style-skill" checkout --quiet FETCH_HEAD; \
	else \
		mkdir -p "$(SKILLS_DIR)" && \
		git clone --quiet --depth 1 --branch "$(PLONE_DOC_STYLE_REF)" \
			"$(PLONE_DOC_STYLE_REPO)" "$(SKILLS_DIR)/plone-doc-style-skill"; \
	fi
	@# .agents/skills is read by most agents, .claude/skills by Claude Code.
	@for dir in .agents/skills .claude/skills; do \
		mkdir -p "$$dir" && \
		ln -sfn "../../$(SKILLS_DIR)/plone-doc-style-skill/skills/author" "$$dir/plone-doc-style"; \
	done
	@echo "Installed plone-doc-style into .agents/skills and .claude/skills"

# Without this, the catch-all rule below would match the Makefile itself.
Makefile: ;

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
