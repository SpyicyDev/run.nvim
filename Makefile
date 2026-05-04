.PHONY: test test-watch lint fmt fmt-check clean

NVIM ?= nvim
STYLUA ?= stylua

test:
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/run/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

test-watch:
	@command -v entr >/dev/null || { echo "install 'entr' to use test-watch"; exit 1; }
	@find lua plugin tests -name '*.lua' | entr -c $(MAKE) test

lint fmt-check:
	@$(STYLUA) --check lua plugin tests

fmt:
	@$(STYLUA) lua plugin tests

clean:
	@rm -rf .tests/
