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

cosmic_version := 2026-02-02-a36771f
cosmic_url := https://github.com/whilp/cosmic/releases/download/$(cosmic_version)/cosmic-lua
cosmic_sha := a1fc4d47e80bd61173a09c3c4aef3dc10339588f6e2ab39e75a9cab9d2fae7d7
cosmic_bin := cosmic-lua

claude_version := 2.1.29
claude_url := https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/$(claude_version)/linux-x64/claude
claude_sha := 4363a3acd8c39c645a7460ffba139d062ca38ddf40362508ea0be20159c4398c
claude_bin := claude

smokescreen_sha := eae81044dc8309bd7de5782be587cccffc1c4084
smokescreen_url := https://github.com/stripe/smokescreen/archive/$(smokescreen_sha).tar.gz

# Define paths for each dep
$(foreach d,$(deps),$(eval $(d)_path := $(o)/$($(d)_bin)))

COSMIC := $(cosmic_path)
CLAUDE := $(claude_path)
SMOKESCREEN := $(o)/smokescreen

scenarios := $(wildcard scenario-*)
only ?=
match = $(if $(only),$(if $(findstring $(only),$(1)),$(1)),$(1))
results := $(foreach s,$(scenarios),$(call match,$(o)/$(s).got))

.PHONY: help
help:
	@echo "usage: make <target>"
	@echo ""
	@echo "targets:"
	@echo "  eval               run all evals (local, unsandboxed)"
	@echo "  eval-sandbox       run one eval in a network-restricted container"
	@echo "  deps               download cosmic-lua and claude"
	@echo "  list-scenarios     list scenarios as JSON"
	@echo "  summary            summarize eval results"
	@echo "  clean              remove build artifacts"
	@echo ""
	@echo "  only=X             filter to scenario matching X"

.PHONY: deps
deps: $(COSMIC) $(CLAUDE) $(SMOKESCREEN)

.PHONY: eval-sandbox
eval-sandbox: $(COSMIC) $(CLAUDE) $(SMOKESCREEN)
	COSMIC_URL=$(cosmic_url) $(COSMIC) scripts/eval-sandbox.tl $(only)

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
	-@CLAUDE=$(CLAUDE) COSMIC_URL=$(cosmic_url) $(COSMIC) scripts/run-eval.tl $< > $(basename $@).out 2> $(basename $@).err; echo $$? > $@

# Generate download rules for each dep
define dep_rule
$($(1)_path): | $(o)/.
	@curl -fsSL -o $$@ $($(1)_url)
	@echo "$($(1)_sha)  $$@" | sha256sum -c - >/dev/null
	@chmod +x $$@
endef
$(foreach d,$(deps),$(eval $(call dep_rule,$(d))))

$(SMOKESCREEN): | $(o)/.
	@curl -fsSL $(smokescreen_url) | tar -xz -C $(o)
	@cd $(o)/smokescreen-$(smokescreen_sha) && CGO_ENABLED=0 go build -o $(CURDIR)/$@ .
	@rm -rf $(o)/smokescreen-$(smokescreen_sha)

%/.:
	@mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(o)
