.SECONDEXPANSION:
.SECONDARY:
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := help

MAKEFLAGS += --no-print-directory
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

o := o

COSMIC_VERSION := 2026-02-01-51d09b1
COSMIC_URL := https://github.com/whilp/cosmic/releases/download/$(COSMIC_VERSION)/cosmic-lua
COSMIC_SHA := 36b0633d20e5cffe03c1862a2301fed553c6c180b1a2adbd264bcf4ca2d4b0e8
COSMIC := $(o)/cosmic-lua

CLAUDE_VERSION := 2.1.29
CLAUDE_BUCKET := https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
CLAUDE_PLATFORM := linux-x64
CLAUDE_SHA := 4363a3acd8c39c645a7460ffba139d062ca38ddf40362508ea0be20159c4398c
CLAUDE := $(o)/claude

scenarios := $(wildcard scenario-*)
only ?=
match = $(if $(only),$(if $(findstring $(only),$(1)),$(1)),$(1))
results := $(foreach s,$(scenarios),$(call match,$(o)/$(s).got))

.PHONY: help
help:
	@echo "usage: make <target>"
	@echo ""
	@echo "targets:"
	@echo "  eval            run all evals"
	@echo "  eval only=X     run evals matching X"
	@echo "  list-scenarios  list scenarios as JSON"
	@echo "  clean           remove build artifacts"

.PHONY: list-scenarios
list-scenarios: $(COSMIC)
	@$(COSMIC) scripts/list-scenarios.tl $(only)

.PHONY: eval
eval: $(o)/eval-summary.txt

.PHONY: summary
summary: $(COSMIC)
	@$(COSMIC) scripts/summarize.tl $(wildcard $(o)/*.got)

$(o)/eval-summary.txt: $(results) $(COSMIC) | $(o)/.
	@$(COSMIC) scripts/summarize.tl $(filter %.got,$^) | tee $@

$(o)/%.got: % $(COSMIC) $(CLAUDE) | $$(@D)/.
	@echo "Running: $<"
	-@$(COSMIC) scripts/run-eval.tl $< > $(basename $@).out 2> $(basename $@).err; echo $$? > $@

$(COSMIC): | $(o)/.
	curl -fsSL -o $@ $(COSMIC_URL)
	@echo "$(COSMIC_SHA)  $@" | sha256sum -c -
	chmod +x $@

$(CLAUDE): | $(o)/.
	curl -fsSL -o $@ $(CLAUDE_BUCKET)/$(CLAUDE_VERSION)/$(CLAUDE_PLATFORM)/claude
	@echo "$(CLAUDE_SHA)  $@" | sha256sum -c -
	chmod +x $@

%/.:
	@mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(o)
