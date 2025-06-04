# Airbyte Destination Connector for SurrealDB

This is the repository for developing the Airbyte SurrealDB destination connector.

The actual connector code is located in the [destination-surrealdb](./destination-surrealdb) directory, which will eventually be contributed to [connectors](https://github.com/airbytehq/airbyte/tree/master/airbyte-integrations/connectors) in the Airbyte repository.

### Using Published Images

You can pull and use the published images:

```bash
# Pull latest multi-architecture image
docker pull ghcr.io/surrealdb/airbyte-destination-surrealdb:latest

# Pull specific version
docker pull ghcr.io/surrealdb/airbyte-destination-surrealdb:v0.1.0

# Pull specific commit
docker pull ghcr.io/surrealdb/airbyte-destination-surrealdb:a1b2c3d
```

## Development

We have two options for developing the connector:

- [devcontainer](#devcontainer)
- [Nix](#nix)

### devcontainer

**Connector testing with local Airbyte instance**

You can reopen this repository by clicking `Reopen in Container` on VS Code or Cursor, and run `make airbyte-dev` to install Airbyte and `airbyte-ci` dependencies within the dev env.

It will then print a comprehensive set of instructions for getting started with the connector testing.

See [devcontainer.md](./devcontainer.md) for more details.

**Connector development**

There's a separate devcontainer under the `destination-surrealdb` directory.

Open the directory in VS Code or Cursor, do `Reopen in Container`, and you can run `poetry run python -m pytest` to run the tests.

### Nix

To get started, install `nix` and run `make develop`- it will clone the Airbyte repository, run `nix develop`, activate a venv, and install Airbyte and `airbyte-ci` dependencies within the dev env.

You can then `cd airbyte` and run various `airbyte-ci` commands to test the SurrealDB connector and even other connectors.

Note that you must copy `docs/integrations/surrealdb{-migrations,}.md` files to `airbyte/docs/integrations` so let the connector passing some `airbyte-ci` acceptance test cases.

Roadmap:

- [x] Implement the destination connector [destination_surrealdb](./destination-surrealdb)
- [x] Documentation [docs](./docs/integrations/destinations)
- [x] Container image for the connector (Run `airbyte-ci build` to build the image)
- [x] Unit tests [unit_test](./destination-surrealdb/unit_tests)
- [x] Integration test data [integration_tests](./destination-surrealdb/integration_tests)
- [x] Integration test cases
- [ ] Submit a pull request to [the Airbyte repository](https://github.com/airbytehq/airbyte/tree/master/airbyte-integrations/connectors)
- [ ] Be a [partner certified destination](https://docs.airbyte.com/platform/connector-development/partner-certified-destinations#definitions)
