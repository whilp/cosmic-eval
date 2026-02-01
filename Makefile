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
COSMIC := $(o)/cosmic-lua

scenarios := $(wildcard scenario-*)
only ?=
match = $(if $(only),$(if $(findstring $(only),$(1)),$(1)),$(1))
results := $(foreach s,$(scenarios),$(call match,$(o)/$(s).got))

.PHONY: help
help:
	@echo "usage: make <target>"
	@echo ""
	@echo "targets:"
	@echo "  eval          run all evals"
	@echo "  eval only=X   run evals matching X"
	@echo "  clean         remove build artifacts"

.PHONY: eval
eval: $(o)/eval-summary.txt

$(o)/eval-summary.txt: $(results) | $(o)/.
	@echo ""; echo "=== Summary ==="; \
	passed=0; failed=0; \
	for f in $(filter %.got,$^); do \
		name=$$(basename $$f .got); \
		code=$$(cat $$f); \
		if [ "$$code" = "0" ]; then \
			echo "✅ $$name"; \
			passed=$$((passed + 1)); \
		else \
			echo "❌ $$name (exit $$code)"; \
			failed=$$((failed + 1)); \
		fi; \
	done; \
	echo ""; echo "Passed: $$passed  Failed: $$failed"; \
	[ "$$failed" = "0" ]

$(o)/%.got: % $(COSMIC) | $$(@D)/.
	@echo "Running: $<"
	-@$(COSMIC) scripts/run-eval.tl $< > $(basename $@).out 2> $(basename $@).err; echo $$? > $@

$(COSMIC): | $(o)/.
	curl -fsSL -o $@ $(COSMIC_URL)
	chmod +x $@

%/.:
	@mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(o)
