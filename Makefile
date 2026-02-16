TESTS_INIT=tests/minimal_init.lua
TESTS_RELOAD=tests/reload.lua
TESTS_DIR=tests/
E2E_DIR=tests/e2e

.PHONY: test e2e-test behavioral-test all-tests

test:
	@NVIM_APPNAME=phptools_test nvim \
	--headless \
	--noplugin \
	-u ${TESTS_RELOAD} \
	-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }" \
	-c "qa!"

e2e-test:
	@echo "Running E2E tests (module/feature coverage - 70 tests)..."
	@${E2E_DIR}/run_tests.sh

behavioral-test:
	@echo "Running behavioral E2E tests (real user workflows - 150 comprehensive tests)..."
	@${E2E_DIR}/run_behavioral_tests.sh

all-tests: e2e-test behavioral-test test
	@echo ""
	@echo "✓ All test suites completed successfully!"
	@echo "  - Unit tests: 54+ tests (Plenary/Busted)"
	@echo "  - E2E tests: 70 tests (module/feature coverage)"
	@echo "  - Behavioral tests: 150 tests (real user workflows + comprehensive scenarios + composer edge cases)"
