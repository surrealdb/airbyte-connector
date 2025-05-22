# This Makefile automates the setup, build, and testing process for the
# Airbyte SurrealDB destination connector. It manages cloning the main
# Airbyte repository and symlinking the local connector code into the
# correct directory structure, allowing the use of 'airbyte-ci' tools.

# Variables
AIRBYTE_REPO_URL := https://github.com/airbytehq/airbyte.git
AIRBYTE_DIR := airbyte
CONNECTOR_NAME := destination-surrealdb
CONNECTOR_DIR := $(CONNECTOR_NAME)
DOCS_DIR := docs/integrations/destinations
AIRBYTE_CONNECTORS_DIR := $(AIRBYTE_DIR)/airbyte-integrations/connectors
AIRBYTE_DOCS_DIR := $(AIRBYTE_DIR)/docs/integrations/destinations

.PHONY: all setup-dev build test clean develop

all: build test

# Setup development environment: Clones Airbyte repo and symlinks the connector
setup-dev: $(AIRBYTE_DIR)
	@echo "Development environment setup."

$(AIRBYTE_DIR):
	@echo "Cloning Airbyte repository into $(AIRBYTE_DIR)..."
	git clone --depth 1 $(AIRBYTE_REPO_URL) $(AIRBYTE_DIR)
	@echo "Copying $(CONNECTOR_NAME) to the Airbyte repository..."
	rm -rf $(AIRBYTE_CONNECTORS_DIR)/$(CONNECTOR_NAME)
	cp -r $(CONNECTOR_DIR) $(AIRBYTE_CONNECTORS_DIR)/$(CONNECTOR_NAME)
	@echo "Copied $(CONNECTOR_NAME) to the Airbyte repository"
	@echo "Copying docs to the Airbyte repository..."
	cp $(DOCS_DIR)/surrealdb.md $(AIRBYTE_DOCS_DIR)/surrealdb.md
	cp $(DOCS_DIR)/surrealdb-migrations.md $(AIRBYTE_DOCS_DIR)/surrealdb-migrations.md
	@echo "Copied docs to the Airbyte repository"

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

# This is the old way to install Airbyte dependencies within the Nix shell.
# It is not used anymore, but kept here for reference.
# Use the devcontainer instead. The devcontainer runs `make airbyte-dev` below on startup.
.PHONY: deps
deps:
	@echo "Installing Airbyte dependencies..."
	cd $(AIRBYTE_DIR) && \
	  python -m venv .venv && \
	  . .venv/bin/activate && \
	  pip install poetry && \
	  pip install pipx && \
	  make tools.airbyte-ci-dev.install

.PHONY: airbyte-dev
airbyte-dev: $(AIRBYTE_DIR)
	@echo "Installing Airbyte dependencies..."
	cd $(AIRBYTE_DIR) && \
	  pip install --user poetry && \
	  poetry config virtualenvs.in-project true && \
	  pip install pipx --user poetry && \
	  pipx install uv && \
	  make tools.airbyte-ci-dev.install
	@echo "Airbyte devenv is ready. Run `cd $(AIRBYTE_DIR)` to get started!"
	@echo " 1. Run `airbyte-ci connectors --name destination-surrealdb build` to build the connector."
	@echo " 2. Run `docker run --rm airbyte/destination-surrealdb:dev spec` to the build worked and the image is available within the local docker daemon."
	@echo " 3. Run `abctl local install" to start the local, kind-based installation of Airbyte."
	@echo " 4. Run `kubectl create -f ../surrealdb.yaml` to deploy a local SurrealDB instance."
	@echo " 5. Run `kind load docker-image --name airbyte-abctl airbyte/destination-surrealdb:dev` to load the image into the kind cluster."
	@echo " 6. Run `abctl local credentials` to get the credentials for the local Airbyte instance."
	@echo " 7. Open http://localhost:8000, choose whatever email, and submit the password you got from the previous step."
	@echo " 8. Go to `Settings > Workspace > Destinations` and click the "New Connector" button."
	@echo "    Connector display name: SurrealDB"
	@echo "    Docker repository name: airbyte/destination-surrealdb"
	@echo "    Docker image tag: dev"
	@echo " 9. Click `Add` to create the connector."
	@echo "10. It should show up `New destination` form. Put in the following values:"
	@echo "    surrealdb_database: airbyte"
	@echo "    surrealdb_namespace: airbyte"
	@echo "    surrealdb_password: root"
	@echo "    surrealdb_url: ws://surrealdb.default:8000/rpc"
	@echo "    surrealdb_username: root"
	@echo "11. Click `Set up destination` to create the destination."
	@echo "    If the creation fails with `An exception occurred: gaierror(-5, 'No address associated with hostname')`, verify that you deployed the SurrealDB instance onto the same kind cluster as Airbyte."
	@echo "    If the connection check fails with `An exception occurred: InvalidStatus(Response(status_code=404, reason_phrase='Not Found', ...` verify that you've added /rpc suffix to the URL."
	@echo "12. Click `Create your first connection` and configure the source and destination."
	@echo "    Source: CSV (epidemiology, https://storage.googleapis.com/covid19-open-data/v2/latest/epidemiology.csv)"
	@echo "    Destination: Select an existing destination > SurrealDB"
	@echo "13. Select the stream with the following values:"
	@echo "    Replicate Source"
	@echo "    Schema: epidemiology"
	@echo "    Sync mode: Full refresh / Overwrite"
	@echo "14. Click `Next`"
	@echo "15. Complete the connection configuration with the following values:"
	@echo "    Connection name: csv-to-sdb-test"
	@echo "    Schedule type: Manual"
	@echo "    Destination Namespace: Destination-defined"
	@echo "16. Click `Submit`.
	@echo "17. Click `Sync now` to start the sync."
	@echo "See devcontainer.md for more details."
