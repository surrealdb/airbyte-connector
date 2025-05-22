# Dev Container

This project uses a devcontainer to provide a consistent development environment.

ToC:

- [How to use](#how-to-use)
- [How to launch local Airbyte](#how-to-launch-local-airbyte)
- [How to test the connector with the local Airbyte](#how-to-test-the-connector-with-the-local-airbyte)

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

## How to test the connector with the local Airbyte

To test the connector with the local Airbyte, you need to first install the connector in the local Airbyte.

This is usually done by browsing to the Airbyte web UI, and then clicking the "New Connector" button on  `Settings > Workspace > Destinations`.

It will then ask you the following information:

- Connector display name
- Docker repository name
- Docker image tag
- Connector documentation URL (Ooptional)

Once you fill in the required fields, you can click the "Add" button to create the connector.

Once the connector is created, you can test it via connections.

To create a connection, go to `Connections > New connection`.

Do the following to create a connection:

- Select the source of your choice
- Select the destination `SurrealDB` we've just created
- Select streams
- Configure connection settings

Once you've created a connection, you can start it and monitor the progress.
If everything goes well, you should see the data flowing into your SurrealDB instance.
