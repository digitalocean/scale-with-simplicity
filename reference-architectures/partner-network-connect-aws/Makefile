MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))
TEST_SCRIPT_DIR := $(realpath $(MAKEFILE_DIR)/../../test/scripts)

.PHONY: tf-validate
tf-validate:
	@cd terraform && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tflint
tflint:
	@cd terraform &&  $(TEST_SCRIPT_DIR)/tflint.sh

.PHONY: lint
lint: tf-validate tflint

.PHONY: test-unit
test-unit:
	cd test/unit &&  $(TEST_SCRIPT_DIR)/terratest.sh

.PHONY: test-integration
test-integration:
	cd test/integration &&  $(TEST_SCRIPT_DIR)/terratest.sh