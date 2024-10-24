TESTS_INIT=tests/minimal_init.lua
TESTS_RELOAD=tests/reload.lua
TESTS_DIR=tests/

.PHONY: test

test:
	@nvim \
	--headless \
	 --noplugin \
	 -u ${TESTS_RELOAD} \
	 -c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
