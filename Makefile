COSMIC_VERSION := 2026-02-01-51d09b1
COSMIC_URL := https://github.com/whilp/cosmic/releases/download/$(COSMIC_VERSION)/cosmic-lua
COSMIC := o/cosmic-lua

.PHONY: eval clean

$(COSMIC):
	@mkdir -p o
	curl -fsSL -o $@ $(COSMIC_URL)
	chmod +x $@

eval: $(COSMIC)
	$(COSMIC) scripts/run-eval.tl $(SCENARIO)

clean:
	rm -rf o results
