# Dev Container

This project uses a devcontainer to provide a consistent development environment.

ToC:

- [How to use](#how-to-use)
- [How to launch local Airbyte](#how-to-launch-local-airbyte)
- [Deploying SurrealDB](#deploying-surrealdb)
- [How to build the connector](#how-to-build-the-connector)
- [How to test the connector with the local Airbyte](#how-to-test-the-connector-with-the-local-airbyte)
  - [Create a destination definition](#create-a-destination-definition)
  - [Create a connection](#create-a-connection)

## How to use

1. Open the command palette (Ctrl+Shift+P or Cmd+Shift+P)
2. Search for "Dev Containers: Reopen in Container"
3. Click on it to reopen the project in a devcontainer

## How to launch local Airbyte

Run the following command to start Airbyte:

```bash
abctl local install
```

This will install Airbyte in a local Kubernetes cluster.
Note that our devcontainer assumes `kind` and `dind` is available to it, so that `abctl`'s `kind` provider will work.

```bash
$ abctl local install
  INFO    Using Kubernetes provider:
            Provider: kind
            Kubeconfig: /home/vscode/.airbyte/abctl/abctl.kubeconfig
            Context: kind-airbyte-abctl
 SUCCESS  Found Docker installation: version 28.1.1-1                                                                                                            
  INFO    No existing cluster found, cluster 'airbyte-abctl' will be created                                                                                     
 SUCCESS  Port 8000 appears to be available                                                                                                                      
 SUCCESS  Cluster 'airbyte-abctl' created                                                                                                                        
  INFO    Pulling image airbyte/airbyte-base-java-image:3.3.5
  INFO    Pulling image airbyte/async-profiler:1.6.2
  INFO    Pulling image airbyte/bootloader:1.6.2    
  INFO    Pulling image airbyte/connector-builder-server:1.6.2
  INFO    Pulling image airbyte/connector-sidecar:1.6.2
  INFO    Pulling image airbyte/container-orchestrator:1.6.2
  INFO    Pulling image airbyte/cron:1.6.2
  INFO    Pulling image airbyte/db:1.6.2
  INFO    Pulling image airbyte/server:1.6.2
  INFO    Pulling image airbyte/webapp:1.6.2
  INFO    Pulling image airbyte/worker:1.6.2
  INFO    Pulling image airbyte/workload-api-server:1.6.2
  INFO    Pulling image airbyte/workload-init-container:1.6.2
  INFO    Pulling image airbyte/workload-launcher:1.6.2
  INFO    Pulling image minio/minio:RELEASE.2023-11-20T22-40-07Z
  INFO    Pulling image temporalio/auto-setup:1.26
  INFO    Namespace 'airbyte-abctl' created
  INFO    Persistent volume 'airbyte-minio-pv' created
  INFO    Persistent volume 'airbyte-volume-db' created
  INFO    Persistent volume claim 'airbyte-minio-pv-claim-airbyte-minio-0' created
  INFO    Persistent volume claim 'airbyte-volume-db-airbyte-db-0' created
  INFO    Starting Helm Chart installation of 'airbyte/airbyte' (version: 1.6.2)
 SUCCESS  Installed Helm Chart airbyte/airbyte:
            Name: airbyte-abctl
            Namespace: airbyte-abctl
            Version: 1.6.2
            AppVersion: 1.6.2
            Release: 1
  INFO    Starting Helm Chart installation of 'nginx/ingress-nginx' (version: 4.12.2)
 SUCCESS  Installed Helm Chart nginx/ingress-nginx:
            Name: ingress-nginx
            Namespace: ingress-nginx
            Version: 4.12.2
            AppVersion: 1.12.2
            Release: 1
  INFO    No existing Ingress found, creating one
 SUCCESS  Ingress created
 WARNING  Failed to launch web-browser.
          Please launch your web-browser to access http://localhost:8000
 SUCCESS  Airbyte installation complete.
            A password may be required to login. The password can by found by running
            the command abctl local credentials
```

You can then open your browser and access http://localhost:8000 as written in the warning message.
VS Code Remote will automatically port-forward it so that it just works from your host operating system.

The UI will first asks you to provide a preferred email addrses and an organization name.
You can put dummy values there- the only requirement seems to be that the email address looks valid, so something like `foo@example.com` would work.

Once confirmed, it will then ask you to provide the password.

The password should have been already created by abctl for you, which you can locate by running `abctl local credentials`:

```bash
vscode ➜ /workspace $ abctl local credentials
  INFO    Using Kubernetes provider:
            Provider: kind
            Kubeconfig: /home/vscode/.airbyte/abctl/abctl.kubeconfig
            Context: kind-airbyte-abctl
 SUCCESS  Retrieving your credentials from 'airbyte-auth-secrets'
  INFO    Credentials:
            Email: [not set]
            Password: **this is the password you use for logging in via the web UI**
            Client-Id: **redacted**
            Client-Secret: **redacted**
```

> Note that once you've logged in, the `Email` field in the `abctl local credentials` command will be set to the email you used to log in, and it seems to persist across multiple runs of `abctl local install` across different VS Code sessions.
> I have not dug into why. Probably ab data is stored somewhere shared across VS Code sessions, like `$HOME/.airbyte/abctl`?

## Deploying SurrealDB

To test the connector with the local Airbyte, you need to deploy a SurrealDB instance.

It can be done by using our Kubernetes manifest, for example:

```bash
kubectl apply -f surrealdb.yaml
```

This will deploy a SurrealDB instance onto the `default` Kubernetes namespace.

From within the Kubernetes cluster, the SurrealDB instance is available at `surrealdb.default` cluster service name, and the RPC endpoint is `ws://surrealdb.default:8000/rpc`.

Airbyte referes to the SurrealDB instance via the endpoint URL `ws://surrealdb.default:8000/rpc`.

## How to build the connector

To build the connector, you need to build the connector image and push it to a Docker registry or to the local Kubernsetes cluster that is running Airbyte.

```bash
(cd airbyte && airbyte-ci connectors --name destination-surrealdb build)

# Ensure the image is built
docker images | grep destination-surrealdb
```

If you've already started the local Airbyte, you can push the image to the local Kubernetes cluster by running the following command:

```bash
# Ensure the cluster has been created
kind get clusters | grep airbyte

kind load docker-image --name airbyte-abctl airbyte/destination-surrealdb:dev
```

This will make the image available to the local Airbyte.

## How to test the connector with the local Airbyte

To test the connector with the local Airbyte, you need to first install the connector in the local Airbyte.

There are two ways to install the connector in the local Airbyte:

1. [Using the Airbyte web UI](#using-the-airbyte-web-ui)
2. [Using the Airbyte API](#using-the-airbyte-api)

### Using the Airbyte web UI

This is usually done by browsing to the Airbyte web UI, and then clicking the "New Connector" button on  `Settings > Workspace > Destinations`.

It will then ask you the following information:

- Connector display name
- Docker repository name
- Docker image tag
- Connector documentation URL (Ooptional)

Once you fill in the required fields, you can click the "Add" button to create the connector (a.k.a. "destination definition").

### Using the Airbyte API

You can use the ["create a destination definition" API](https://reference.airbyte.com/reference/createdestinationdefinition) which is part of [the Airbyte API](https://docs.airbyte.com/platform/api-documentation#using-the-airbyte-api) to install the connector in the local Airbyte.

First, you need to obtain an API token:

```bash
# Get the client ID and client secret from the abctl local credentials command
export AB_CLIENT_ID=$(NO_COLOR=1 abctl local credentials | grep Client-Id | awk -F': ' '{print $2}')
export AB_CLIENT_SECRET=$(NO_COLOR=1 abctl local credentials | grep Client-Secret | awk -F': ' '{print $2}')

# Ensure the client ID and client secret are set
export | grep AB_

# Get the API token
cat - <<EOF | jq . > token.json
{
  "client_id": "$AB_CLIENT_ID",
  "client_secret": "$AB_CLIENT_SECRET"
}
EOF

export AB_TOKEN=$(curl http://localhost:8000/api/v1/applications/token \
  -H "Content-Type: application/json" \
  -d @token.json | jq -r .access_token)

rm token.json
```

Now, you need to get the workspace ID.

```bash
curl -X GET http://localhost:8000/api/public/v1/workspaces \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN"

# You might want to use the default workspace, which is the first and the only one in the list
export AB_WORKSPACE_ID=$(curl -X GET http://localhost:8000/api/public/v1/workspaces \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[0].workspaceId')

# Ensure it is the workspace you want to use
curl -X GET http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r .name
```

Finally, you can create the destination definition:

```bash
curl -X POST http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" \
  -d '{"name": "SurrealDB", "dockerRepository": "airbyte/destination-surrealdb", "dockerImageTag": "dev"}'

# It might take a few seconds to respond.
# Once created, you might get the rseponse like:
# {"id":"the destination definition ID","name":"surrealdb","dockerRepository":"airbyte/destination-surrealdb","dockerImageTag":"dev","documentationUrl":""}

# Ensure the destination definition is created
curl -X GET http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "SurrealDB")'
```

This will create a destination definition for the SurrealDB connector in the local Airbyte.

## Create a connection

Once the connector (a.k.a. "destination definition") is created, you can test it via connections.

There are two ways to create a connection:

1. [Using the Airbyte web UI](#create-a-connection-using-the-airbyte-web-ui)
2. [Using the Airbyte API](#create-a-connection-using-the-airbyte-api)

### Create a connection using the Airbyte web UI

To create a connection, go to `Connections > New connection`.

Do the following to create a connection:

- Select the source of your choice
- Select the destination `SurrealDB` we've just created
- Select streams
- Configure connection settings

Once you've created a connection, you can start it and monitor the progress.
If everything goes well, you should see the data flowing into your SurrealDB instance.

### Create a connection using the Airbyte API

You can use the ["create a connection" API](https://reference.airbyte.com/reference/createconnection) which is part of [the Airbyte API](https://docs.airbyte.com/platform/api-documentation#using-the-airbyte-api) to create a connection.

You need to create a "source" and a "destination" first, and then create a "connection" between them.

Each connection can have detailed settings, but here we will be using [the default settings](https://reference.airbyte.com/reference/createconnection#default-connection-settings).

First, we [create a source](https://reference.airbyte.com/reference/createsource) (file source in this case):

```bash
export SOURCE_DEFINITION_ID=$(curl -X GET http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/sources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.dockerRepository == "airbyte/source-file") | .id' | head -n 1)

cat - <<EOF > source.json
{
  "name": "my-file-source",
  "definitionId": "${SOURCE_DEFINITION_ID}",
  "workspaceId": "${AB_WORKSPACE_ID}",
  "configuration": {
    "sourceType": "file",
    "dataset_name": "my_dataset",
    "format": "csv",
    "url": "https://storage.googleapis.com/covid19-open-data/v2/latest/epidemiology.csv",
    "provider": {
      "storage": "HTTPS",
      "user_agent": true
    }
  }
}
EOF

curl -X POST http://localhost:8000/api/public/v1/sources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" \
  -d @source.json

# Ensure the source is created
curl -X GET http://localhost:8000/api/public/v1/sources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "my-file-source")'

# If you see redundant sources, delete it like:
AB_SOURCE_ID="the source ID"
curl -X DELETE http://localhost:8000/api/public/v1/sources/${AB_SOURCE_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN"
```

We then [create a destination](https://reference.airbyte.com/reference/createdestination) (SurrealDB destination in this case):

```bash
export DESTINATION_DEFINITION_ID=$(curl -X GET http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.dockerRepository == "airbyte/destination-surrealdb") | .id' | head -n 1)

cat - <<EOF > destination.json
{
  "name": "my-surrealdb-destination",
  "definitionId": "${DESTINATION_DEFINITION_ID}",
  "workspaceId": "${AB_WORKSPACE_ID}",
  "configuration": {
    "destinationType": "",
    "surrealdb_url": "ws://surrealdb.default:8000/rpc",
    "surrealdb_namespace": "airbyte",
    "surrealdb_database": "airbyte",
    "surrealdb_username": "root",
    "surrealdb_password": "root"
  }
}
EOF

curl -X POST http://localhost:8000/api/public/v1/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" \
  -d @destination.json

# Ensure the destination is created
curl -X GET http://localhost:8000/api/public/v1/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.definitionId == "'"${DESTINATION_DEFINITION_ID}"'")'

# If you see redundant destinations, delete it like:
AB_DESTINATION_ID="the destination ID"
curl -X DELETE http://localhost:8000/api/public/v1/destinations/${AB_DESTINATION_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN"
```

We then [create a connection](https://reference.airbyte.com/reference/createconnection) between the source and the destination:

```bash
export AB_SOURCE_ID=$(curl -X GET http://localhost:8000/api/public/v1/sources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "my-file-source") | .sourceId')

export AB_DESTINATION_ID=$(curl -X GET http://localhost:8000/api/public/v1/destinations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "my-surrealdb-destination") | .destinationId')

curl -X POST http://localhost:8000/api/public/v1/connections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" \
  -d '{"name": "my-csv-to-surrealdb-connection", "sourceId": "'"${AB_SOURCE_ID}"'", "destinationId": "'"${AB_DESTINATION_ID}"'", "workspaceId": "'"${AB_WORKSPACE_ID}"'"}'

# Ensure the connection is created
curl -X GET http://localhost:8000/api/public/v1/connections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "my-csv-to-surrealdb-connection")'

# Take note of the connection ID
export AB_CONNECTION_ID=$(curl -X GET http://localhost:8000/api/public/v1/connections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.name == "my-csv-to-surrealdb-connection") | .connectionId')
```

Once the connection is created, you can start it and monitor the progress.

To start (or manually start syncing the destination with the source), you can use the [Create Job](https://reference.airbyte.com/reference/createjob) API:

```bash
export AB_JOB_ID=$(curl -X POST http://localhost:8000/api/public/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" \
  -d '{"connectionId": "'"${AB_CONNECTION_ID}"'", "jobType": "sync"}' | jq -r .jobId)

# Ensure the job is created
curl -X GET http://localhost:8000/api/public/v1/jobs/${AB_JOB_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN"
```

It may take a while for the job to complete.

To wait for the job to complete, you can use the [Get Job](https://reference.airbyte.com/reference/getjob) API:

```bash
AB_JOB_STATUS=$(curl -X GET http://localhost:8000/api/public/v1/jobs/${AB_JOB_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq -r .status)

i=0
TIMEOUT=300
while [ "$AB_JOB_STATUS" = "running" ]; do
  i=$((i+1))
  if [ $i -gt $TIMEOUT ]; then
    echo "Job is still running after $TIMEOUT seconds. Aborting."
    exit 1
  fi
  sleep 1
  curl -s -X GET http://localhost:8000/api/public/v1/jobs/${AB_JOB_ID} \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AB_TOKEN" > job.json
  AB_JOB_STATUS=$(jq -r .status job.json)
done

curl -X GET http://localhost:8000/api/public/v1/jobs/${AB_JOB_ID} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AB_TOKEN" | jq .
```

If everything goes well, you should see the data flowing into your SurrealDB instance.

To run the SurrealDB SQL shell for checking the data in the SurrealDB instance, you can use the following command:

```bash
export SURREALDB_POD_NAME=$(kubectl get pods -l app=surrealdb -o jsonpath='{.items[0].metadata.name}')
kubectl exec $SURREALDB_POD_NAME -it -- /surreal sql -u root -p root --ns airbyte --db airbyte
```
