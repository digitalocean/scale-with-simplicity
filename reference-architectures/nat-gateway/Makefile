MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))
TEST_SCRIPT_DIR := $(realpath $(MAKEFILE_DIR)/../../test/scripts)

.PHONY: tf-validate-infra
tf-validate-infra:
	@cd terraform/1-infra && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tf-validate-routes
tf-validate-routes:
	@cd terraform/2-routes && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tf-validate
tf-validate: tf-validate-infra tf-validate-routes

.PHONY: tflint
tflint:
	@cd terraform && $(TEST_SCRIPT_DIR)/tflint.sh

.PHONY: go-mod-check
go-mod-check:
	@cd test && $(TEST_SCRIPT_DIR)/go-mod-tidy-check.sh

.PHONY: lint
lint: tf-validate tflint go-mod-check

.PHONY: test-unit
test-unit:
	cd test/unit && $(TEST_SCRIPT_DIR)/terratest.sh

.PHONY: test-integration
test-integration:
	cd test/integration && $(TEST_SCRIPT_DIR)/terratest.sh
