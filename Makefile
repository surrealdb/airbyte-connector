# This Makefile automates the setup, build, and testing process for the
# Airbyte SurrealDB destination connector. It manages cloning the main
# Airbyte repository and symlinking the local connector code into the
# correct directory structure, allowing the use of 'airbyte-ci' tools.

# Variables
AIRBYTE_REPO_URL := https://github.com/airbytehq/airbyte.git
AIRBYTE_DIR := airbyte
CONNECTOR_NAME := destination-surrealdb
CONNECTOR_DIR := $(CONNECTOR_NAME)
AIRBYTE_CONNECTORS_DIR := $(AIRBYTE_DIR)/airbyte-integrations/connectors

.PHONY: all setup-dev build test clean develop

all: build test

# Setup development environment: Clones Airbyte repo and symlinks the connector
setup-dev: $(AIRBYTE_DIR)
	@echo "Development environment setup."

$(AIRBYTE_DIR):
	@echo "Cloning Airbyte repository into $(AIRBYTE_DIR)..."
	git clone --depth 1 $(AIRBYTE_REPO_URL) $(AIRBYTE_DIR)
	@echo "Creating symlink for $(CONNECTOR_NAME)..."
	ln -s ../../../$(CONNECTOR_DIR) $(AIRBYTE_CONNECTORS_DIR)/$(CONNECTOR_NAME)
	@echo "Symlink created at $(AIRBYTE_CONNECTORS_DIR)/$(CONNECTOR_NAME)"

# Build the connector using airbyte-ci
build: setup-dev
	@echo "Building $(CONNECTOR_NAME) connector..."
	cd $(AIRBYTE_DIR) && airbyte-ci connectors --name $(CONNECTOR_NAME) build

# Run tests for the connector using airbyte-ci
test: setup-dev
	@echo "Testing $(CONNECTOR_NAME) connector..."
	cd $(AIRBYTE_DIR) && airbyte-ci connectors --name=$(CONNECTOR_NAME) test -x qa_checks

# Clean up the development environment
clean:
	@echo "Cleaning up..."
	rm -rf $(AIRBYTE_DIR)
	@echo "Removed $(AIRBYTE_DIR)."

# Setup development environment using Nix (as described in README)
.PHONY: develop
develop:
	@echo "Running nix develop to enter the development environment..."
	@echo "Follow instructions within the Nix shell if needed (e.g., activate venv, install deps)."
	nix develop

.PHONY: deps
deps:
	@echo "Installing Airbyte dependencies..."
	cd $(AIRBYTE_DIR) && \
	  python -m venv .venv && \
	  . .venv/bin/activate && \
	  pip install poetry && \
	  pip install pipx && \
	  make tools.airbyte-ci-dev.install
