SHELL := /bin/bash

export HELP_FILTER ?= help|terraform|lint
export README_DEPS ?= docs/targets.md docs/terraform-split.md

-include $(shell curl -sSL -o .build-harness-ext "https://go.sr2.uk/build-harness"; echo .build-harness-ext)

## Lint terraform code
lint:
	$(SELF) readme/lint terraform/install terraform/get-modules terraform/lint terraform/validate tflint
