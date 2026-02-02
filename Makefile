.SECONDEXPANSION:
.SECONDARY:
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := help

MAKEFLAGS += --no-print-directory
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

o := o

# Dependencies
deps := cosmic claude

cosmic_version := 2026-02-01-51d09b1
cosmic_url := https://github.com/whilp/cosmic/releases/download/$(cosmic_version)/cosmic-lua
cosmic_sha := 36b0633d20e5cffe03c1862a2301fed553c6c180b1a2adbd264bcf4ca2d4b0e8
cosmic_bin := cosmic-lua

claude_version := 2.1.29
claude_url := https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/$(claude_version)/linux-x64/claude
claude_sha := 4363a3acd8c39c645a7460ffba139d062ca38ddf40362508ea0be20159c4398c
claude_bin := claude

# Define paths for each dep
$(foreach d,$(deps),$(eval $(d)_path := $(o)/$($(d)_bin)))

COSMIC := $(cosmic_path)
CLAUDE := $(claude_path)

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
	-@CLAUDE=$(CLAUDE) $(COSMIC) scripts/run-eval.tl $< > $(basename $@).out 2> $(basename $@).err; echo $$? > $@

# Generate download rules for each dep
define dep_rule
$($(1)_path): | $(o)/.
	curl -fsSL -o $$@ $($(1)_url)
	@echo "$($(1)_sha)  $$@" | sha256sum -c -
	chmod +x $$@
endef
$(foreach d,$(deps),$(eval $(call dep_rule,$(d))))

%/.:
	@mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(o)
