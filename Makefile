SHELL := /bin/bash

export HELP_FILTER ?= help|terraform|lint

# List of targets the `readme` target should call before generating the readme
export README_DEPS ?= docs/targets.md docs/terraform-split.md

-include $(shell curl -sSL -o .build-harness-ext "https://gitlab.com/sr2c/build-harness-extensions/-/raw/main/Makefile.bootstrap"; echo .build-harness-ext)

## Lint terraform code
lint:
	$(SELF) terraform/install terraform/get-modules terraform/lint terraform/validate tflint
