## Introduction

Thank you for your interest in contributing to Scale with Simplicity, DigitalOcean's home for easily deployable Reference Architectures and Patterns. While most contributions might come from within DigitalOcean, we welcome and value input from the broader community.

## Getting Started

This section covers what you need to begin working with and the basic structure of a Reference Architecture.

### Dependencies

Before you add or deploy any Reference Architecture (RA), ensure you have the following installed and configured:

* **Terraform** (v1.5.0 or later): to author, plan, and apply IaC configurations as part of the development workflow.
* **Go** (1.18+): required for Terratest-based unit and integration tests.
* **DigitalOcean Account & API Token**: with appropriate permissions to create and destroy the resources your RA will deploy.

### Anatomy of a Reference Architecture

A **Reference Architecture (RA)** is a curated, end-to-end deployment blueprint that demonstrates how to assemble production‑grade components into a complete solution on DigitalOcean. Each RA:

* **Orchestrates Reusable Modules**: Relies on purpose‑built Terraform modules from the `modules/` directory (see [TERRAFORM-MODULE-LIBRARY.md](./TERRAFORM-MODULE-LIBRARY.md)) for common services (VPC, Load Balancers, Managed Databases, etc.).
* **Adds Composition Logic**: Encapsulates higher‑level wiring, parameter choices, and orchestration that guide a user through deploying a full solution.
* **Includes Diagrams & Documentation**: Provides a visual overview (`<ra-slug>.png`) and step‑by‑step instructions (`README.md`) so Solutions Architects and end users understand the design.
* **Ships Automated Tests**: Carries unit and integration tests (via Terratest) to verify both plan outputs and full apply/destroy cycles, ensuring ongoing reliability.

#### When to Use Existing Modules vs. Create New

Terraform modules should only be created when they provide clear value by orchestrating multiple resources or encapsulating complex logic that would otherwise be repeated across RAs. In other words, a module is justified when:

* **Cross‑cutting Composition**: It wires together several related resources (e.g., setting up multi‑region networking, global load balancer stacks, or multi‑tunnel VPN configurations) as a cohesive unit.
* **Parameter-driven Variability**: It exposes configuration inputs and outputs that let different RAs customize the same underlying pattern without duplicating HCL code (e.g., `name_prefix`, CIDR blocks, health checks).
* **Reusability Across RAs**: It would be reused by more than one RA in this repo or by our broader Solutions Architect community.

By contrast, do **not** create a module if you only need to define a handful of resources specific to a single RA. In those cases, place them directly in the RA’s `main.tf` alongside module calls.

When in doubt, ask: *“Will this code be used by multiple architectures or represent a distinct orchestration pattern?”* If yes then create a module otherwise, keep it in the RA’s Terraform files.

This guideline helps ensure our module library remains focused on widely applicable patterns, while RAs retain flexibility to implement one‑off or highly tailored resources without unnecessary abstraction.

## Contributing to Modules

Reusable Terraform modules are located in the `modules/` directory. When modifying or adding modules:

### Module Structure

Each module follows this structure:

```
modules/<module-name>/
├── main.tf           # Core module logic
├── variables.tf      # Input variables
├── outputs.tf        # Module outputs
├── terraform.tf      # Provider requirements
├── README.md         # Usage documentation
├── Makefile          # Lint and test targets
└── test/
    ├── go.mod        # Test dependencies
    ├── go.sum
    └── *_test.go     # Unit tests
```

### Running Module Tests

```bash
cd modules/<module-name>
make lint        # Run terraform validate, fmt, tflint
make test-unit   # Run unit tests
```

### Updating Modules

When updating a module:
1. Make changes to the module code
2. Run `make lint` and `make test-unit` in the module directory
3. Test affected reference architectures that use the module
4. Update the module's README.md if inputs/outputs change

### Referencing Modules from RAs

Reference modules using relative paths from your Terraform configuration:

```hcl
module "multi_region_vpc" {
  source      = "../../../modules/multi-region-vpc"
  name_prefix = var.name_prefix
  vpcs        = var.vpcs
}
```

## Adding a Reference Architecture

When you’re ready to author a new Reference Architecture (RA), follow these steps and conventions to ensure consistency across the scale‑with‑simplicity library.

### Submission Workflow

1. **Fork the repo** and create a feature branch (e.g. `<ra-slug>`).
2. **Create your RA directory** under `reference-architectures/` named `<ra-slug>/` and scaffold the files as described in the **Terraform Files and RA Layout** section.
3. **Add a Makefile** at the root of your RA folder. These Make targets will enable you and our CI system to run tests easily.

```
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
```

5. **Update top-level** `README.md` to include your new RA in the index.
6. **Add integration test workflow** under `.github/workflows/<ra-slug>-integration-test.yaml`. PR checks run automatically for all modules and RAs. See the **CI Integration** section for details.
7. **Push branch** and open a Pull Request. Ensure CI checks pass before requesting review.

### **Terraform Files and RA Layout**

Your Reference Architecture (RA) should adhere to the following directory and file conventions under `reference-architectures/<ra-slug>/`:

```
<ra-slug>/
├── <ra-slug>.png         # Architecture diagram (visual overview)
├── README.md             # Problem statement, prerequisites, deployment steps, cleanup
├── Makefile              # Validate, lint, unit and integration test targets
├── terraform/            # Terraform code
│   ├── main.tf           # Core resources and module invocations
│   ├── variables.tf      # Input variable definitions
│   ├── outputs.tf        # Exported outputs for tests and documentation
│   └── terraform.tf      # Backend configuration & provider blocks
└── test/                 # Terratest code and test data
    ├── go.mod            # Terratest dependencies
    ├── test.tfvars       # Sample variable values for tests
    ├── unit/             # Unit tests (plan validations)
    │   └── unit_test.go
    └── integration/      # End-to-end apply/destroy tests
        └── apply_destroy_test.go
```

* Feel free to copy files from other RAs, but be sure to replace/update anything related with the original RA.
* Place any RA-specific Terraform resources (e.g., inline Droplets, certificates) directly in `main.tf` alongside module calls.
* Reference reusable modules using relative paths (e.g., `source = "../../../modules/multi-region-vpc"`).
* Ensure `variables.tf` only declares inputs required by your RA, and that `outputs.tf` exposes critical values for downstream tests or documentation.
* Keep the Makefile targets aligned with the folder layout so contributors can run `make lint`, `make test-unit`, and `make test-integration` without modification.

### Testing and Validation

Each RA must include both **unit** and **integration** tests using Terratest.

#### Test Module Setup

Each RA’s `test` directory must include a `go.mod` that imports the shared test helpers and Terratest libraries. Example `go.mod` in `reference-architectures/<ra-slug>/test`:

```
module github.com/digitalocean/scale-with-simplicity/reference-architectures/<ra-slug>/test

go 1.24.2

require (
    github.com/digitalocean/scale-with-simplicity/test v0.0.0
    github.com/gruntwork-io/terratest v0.49.0
    github.com/stretchr/testify v1.10.0
)

replace github.com/digitalocean/scale-with-simplicity/test => ../../../test
```

*
The `test` module path should match the RA directory structure.
* `require github.com/digitalocean/scale-with-simplicity/test` pulls in shared helper functions (e.g., `helper.CreateGodoClient`, `helper.TerraformDestroyVpcWithMembers`).
* `replace` points to the root `test` directory in the repository so local changes are picked up.

#### Test Variables File (`test.tfvars`)

* Located under `test/test.tfvars`.
* Defines baseline variable values needed to run both unit and integration tests. `test.tfvars` also makes it easy to deploy the RA using the terraform command line as part of development.
* Should include defaults for non-sensitive inputs (e.g., `droplet_count = 1`, `droplet_size = "s-1vcpu-1gb"`, region and CIDR defaults).
* **Do not** include secrets (API tokens, SSH keys, pre-shared keys). Instead, generate or inject these dynamically within test code using Terratest helpers.
* Tests can override any baseline values inline or by using additional `.tfvars` files.

#### **Unit Tests (Terraform Plan Validation)**

A **bare minimum** unit test should verify that a Terraform plan can successfully execute without errors. If the plan fails, the test fails.

* Use `test_structure.CopyTerraformFolderToTemp` to copy your RA’s Terraform folder into a unique temporary directory. This allows multiple tests to run in parallel without interfering with each other and handles `terraform init` automatically.
* Provide baseline variables from `test.tfvars`, and override specific values inline using `terraform.VarInline`. For example, to override `droplet_count` while loading the rest from `test.tfvars`.

**Minimum unit test example:**

```
package unit

import (
	"github.com/gruntwork-io/terratest/modules/files"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestPlan(t *testing.T) {
    t.Parallel()

    // Copy code to temp dir and init
    testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
    // Copy test.tfvars into temp dir
    err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
    if err != nil {
        t.Fatalf("Failed to copy tfvars file: %v", err)
    }

    // Configure Terraform options with inline override
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: testDir,
        MixedVars:    []terraform.Var{terraform.VarFile("test.tfvars")},
        NoColor:      true,
        PlanFilePath: "plan.out",
    })

    // Run `terraform init` and `terraform plan`; test fails if errors occur
    terraform.InitAndPlanAndShow(t, terraformOptions)
}
```

This pattern ensures a fast, deterministic check that your RA’s HCL is syntactically and logically valid before moving on to deeper functional tests.

**Advanced assertions** (optional): use `InitAndPlanAndShowWithStruct` instead of `InitAndPlanAndShow` . This will return a struct in which you can validate the resource configuration that is part of the plan. See Terratest docs for more detail.

#### **Integration Tests (Terraform Apply & Destroy)**

Integration tests verify that your RA applies, functions, and destroys correctly in a live environment.

* Write the test in `test/integration/apply_destroy_test.go`.
* Use `t.Parallel()` and `test_structure.CopyTerraformFolderToTemp` to isolate each run in its own directory.
* Copy the baseline `test.tfvars` into the temp folder.
* Generate unique names or IDs (e.g., via `random.UniqueId()`) to avoid collisions with concurrent tests.
* Use the DigitalOcean Go SDK (`godo`) helpers to create prerequisites such as test DNS domains or SSH keys. Secrets (API tokens, pre-shared keys) are generated at runtime and not stored in `test.tfvars`.
* Construct `terraform.Options` with both file-based and inline variables. Inline overrides (e.g., `name_prefix`, `domain`, `ssh_key`) replace defaults in `test.tfvars`.
* Use `defer` calls to:
    * Destroy the RA and its VPCs robustly (`helper.TerraformDestroyVpcWithMembers`).
    * Delete test domain and SSH key via helper functions.
* Call `terraform.InitAndApply(t, terraformOptions)`; the test will fail if apply errors occur.
* Optionally, after apply, add functional validations (e.g., HTTP checks against deployed endpoints) before the deferred destroy.

**Minimum integration test example:**

```
import (
	"github.com/digitalocean/scale-with-simplicity/test/constant"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"path/filepath"

	"strings"
	"testing"
)
func TestApplyAndDestroy(t *testing.T) {
    t.Parallel()
	// Generate unique prefix. K8s resources names cannot start with a number
	testNamePrefix := fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))

    // Copy code and tfvars
    testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
    if err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars")); err != nil {
        t.Fatalf("Failed to copy tfvars file: %v", err)
    }

    // Create prerequisites via godo helper
    client := helper.CreateGodoClient()

    // Configure Terraform options
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: testDir,
        MixedVars: []terraform.Var{
            terraform.VarFile("test.tfvars"),
            terraform.VarInline("name_prefix", testNamePrefix),
        },
        NoColor: true,
    })

    // Ensure robust cleanup
    defer helper.TerraformDestroyVpcWithMembers(t, terraformOptions)

    // Apply the RA
    terraform.InitAndApply(t, terraformOptions)
}
```

This pattern ensures an end-to-end lifecycle test, validating deployment, functionality (if added), and cleanup.

### **Test Helper Package**

The `test/helper` package provides a collection of utility functions and structs to facilitate integration testing of the Terraform modules. These helpers interact with the DigitalOcean API to create and manage resources required for tests.

#### **Helper Functions**

These are standalone functions for creating and managing test resources.

| Function                             | Description                                                                                              |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `NewCidrAssigner(...)`               | Creates a new `CidrAssigner` for allocating non-overlapping CIDR blocks.                                   |
| `CreateGodoClient()`                 | Creates and returns a DigitalOcean API client.                                                           |
| `CreateTestDomain(...)`              | Creates a test domain for integration tests.                                                             |
| `DeleteTestDomain(...)`              | Deletes a test domain created for integration tests.                                                     |
| `CreateSshKey(...)`                  | Creates a new SSH key for use in tests.                                                                  |
| `DeleteSshKey(...)`                  | Deletes an SSH key.                                                                                      |
| `TerraformDestroyVpcWithMembers(...)`| A helper function to ensure that a VPC and its member resources are properly destroyed after a test run. |

#### **CidrAssigner**

The `CidrAssigner` struct manages the allocation of CIDR blocks for VPCs and Kubernetes clusters to avoid network conflicts during testing. It is created by the `NewCidrAssigner` helper function.

**Methods**

| Method                   | Description                                                                 |
| ------------------------ | --------------------------------------------------------------------------- |
| `GetVpcCidr()`           | Allocates and returns a new CIDR block for a VPC.                           |
| `GetDoksClusterCidr()`   | Allocates and returns a new CIDR block for a DOKS cluster.                  |
| `GetDoksServiceCidr()`   | Allocates and returns a new CIDR block for a DOKS service.                  |
| `GetCidrBlock(...)`      | A generic function to get a CIDR block that does not overlap with existing ones. |

#### **CI Integration**

##### PR Checks (Automatic)

**No workflow file is needed for PR checks.** A single dynamic workflow (`.github/workflows/pr-check.yaml`) automatically detects and tests any changed modules or reference architectures. When you add a new RA or module with a standard Makefile containing `lint` and `test-unit` targets, PR checks will run automatically.

##### Integration Tests (Per-RA Workflow Required)

Each RA must define an integration test workflow under `.github/workflows/`:

**Integration Test Workflow** (`<ra-slug>-integration-test.yaml`)

```
name: <ra-slug> Apply-Destroy
on:
  schedule:
# "0 2 * * *" is an example, ideally chose some other random time
    - cron: "0 2 * * *"
  workflow_dispatch:

jobs:
  call-common:
    uses: ./.github/workflows/workflow-terraform-integration-test.yaml
    with:
      module_path: reference-architectures/<ra-slug>
    secrets:
      # AWS Creds only needed if RA creates resources or access data from AWS
      AWS_ACCESS_KEY_ID: ${{ secrets.SOLUTIONS_AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.SOLUTIONS_AWS_SECRET_ACCESS_KEY }}
      DIGITALOCEAN_ACCESS_TOKEN: ${{ secrets.TEST_DIGITALOCEAN_ACCESS_TOKEN }}
```

This workflow invokes the **reusable workflow template** `workflow-terraform-integration-test.yaml`.
