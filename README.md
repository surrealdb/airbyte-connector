# Airbyte Destination Connector for SurrealDB

This is the repository for developing the Airbyte SurrealDB destination connector.

The actual connector code is located in the [destination-surrealdb](./destination-surrealdb) directory, which will eventually be contributed to [connectors](https://github.com/airbytehq/airbyte/tree/master/airbyte-integrations/connectors) in the Airbyte repository.

To get started, install `nix` and run `make develop`- it will clone the Airbyte repository, run `nix develop`, activate a venv, and install Airbyte and `airbyte-ci` dependencies within the dev env.

You can then `cd airbyte` and run various `airbyte-ci` commands to test the SurrealDB connector and even other connectors.

Note that you must copy `docs/integrations/surrealdb{-migrations,}.md` files to `airbyte/docs/integrations` so let the connector passing some `airbyte-ci` acceptance test cases.
