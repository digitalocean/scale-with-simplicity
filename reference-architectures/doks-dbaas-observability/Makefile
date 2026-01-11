MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))
TEST_SCRIPT_DIR := $(realpath $(MAKEFILE_DIR)/../../test/scripts)

.PHONY: tf-validate-infra
tf-validate-infra:
	@cd terraform/1-infra && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tf-validate-cluster
tf-validate-cluster:
	@cd terraform/2-cluster && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tf-validate-environment
tf-validate-environment:
	@cd terraform/3-environment && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tf-validate
tf-validate: tf-validate-infra tf-validate-cluster tf-validate-environment

.PHONY: tflint
tflint:
	@cd terraform && $(TEST_SCRIPT_DIR)/tflint.sh

.PHONY: lint
lint: tf-validate tflint

.PHONY: test-unit
test-unit:
	cd test/unit && $(TEST_SCRIPT_DIR)/terratest.sh

.PHONY: test-integration
test-integration:
	cd test/integration && $(TEST_SCRIPT_DIR)/terratest.sh