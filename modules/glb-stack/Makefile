MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))
TEST_SCRIPT_DIR := $(realpath $(MAKEFILE_DIR)/../../test/scripts)

.PHONY: tf-validate
tf-validate:
	@$(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tflint
tflint:
	@$(TEST_SCRIPT_DIR)/tflint.sh

.PHONY: go-mod-check
go-mod-check:
	@cd test && $(TEST_SCRIPT_DIR)/go-mod-tidy-check.sh

.PHONY: lint
lint: tf-validate tflint go-mod-check

.PHONY: test-unit
test-unit:
	cd test && $(TEST_SCRIPT_DIR)/terratest.sh
