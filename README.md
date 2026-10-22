# aks-delivery-bicep-azure-devops
A small ASP.NET Core API, integration tests, a container, and Azure DevOps CI using
[.NET 10 LTS](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core).
Install a current .NET 10 SDK and Docker Desktop. Run commands from the repository root.

## Test

```sh
dotnet test Delivery.slnx -c Release
```

Integration tests exercise both endpoints in memory, checking status, content type,
application identity/version, and health output. They need no Azure access or Docker.

## Run locally

```sh
dotnet run --project app/Delivery.Api --urls http://localhost:8080
```

In another terminal:

```sh
curl --fail http://localhost:8080/
# {"name":"aks-delivery-bicep-azure-devops","version":"1.0.0"}
curl --fail http://localhost:8080/health
# Healthy
```

Stop with Ctrl+C. `/health` is a basic process health check; there are no external
dependencies. The version comes from `<Version>` in the app project.

## Build and run the container

Stop the local app first to free port 8080.

```sh
docker build -t aks-delivery:local .
docker run --rm -d --name aks-delivery-local -p 127.0.0.1:8080:8080 aks-delivery:local
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/health
docker exec aks-delivery-local id
# uid must be nonzero (the .NET image's app user)
docker stop aks-delivery-local
```

The Dockerfile has separate SDK/build and ASP.NET/runtime stages and runs as the
base image's non-root app user on port 8080. Run tests separately before building.

On Apple Silicon, the native SDK and default Docker build run on ARM64.
For a future AKS cluster with AMD64 nodes, build explicitly:

```sh
docker buildx build --platform linux/amd64 --load -t aks-delivery:amd64 .
docker image inspect aks-delivery:amd64 --format '{{.Os}}/{{.Architecture}}'
```

To test this image on the Mac, repeat the container commands with
`docker run --platform linux/amd64` and image `aks-delivery:amd64`. This uses
emulation and may be slower. The image architecture must match the AKS node pool;
an ARM64 test alone does not verify an AMD64 image.

## Azure DevOps CI

[azure-pipelines.yml](azure-pipelines.yml) runs on pushes to `main` and GitHub pull
requests targeting `main`. It installs .NET 10, restores dependencies, runs Release
tests, publishes TRX test results (including failed runs), and builds a
`linux/amd64` image only when the preceding steps succeed.
The image is tagged with the Azure DevOps build ID and automatically pushed to
ACR after successful builds on `main`, using federated Azure authentication.
PR and non-main builds only test and build; they need no Azure connection.

To activate it after reviewing and pushing the YAML:

1. In an Azure DevOps project, open **Pipelines > New pipeline > GitHub**.
2. Authorize access to this GitHub repository and select it.
3. Select **Existing Azure Pipelines YAML file**, choose your branch, and select
   `/azure-pipelines.yml`.
4. Review and run the pipeline. Confirm both tests appear in the **Tests** tab and
   the **Build AMD64 container image** step passes.

The project needs available Microsoft-hosted parallel-job capacity for the
`ubuntu-24.04` agent. Adding this file alone does not create or activate a pipeline.
Local tests/builds do not verify Azure DevOps triggers or task execution; the first
hosted run must verify those.

References: [GitHub integration](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github),
[hosted agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted),
[test result publishing](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/publish-test-results-v2).

## Store images in ACR

Follow [the ACR setup guide](infra/README.md) to deploy the Bicep templates, connect
the managed identity to Azure DevOps using federation, and configure image publishing.
It includes verification and cleanup commands. The dedicated resources must not
be shared with the later Terraform + GitHub Actions implementation.

## Next milestone

Verify a federated image push in Azure DevOps, then add Bicep for AKS and image
pull access. Later work adds deployment, probes, rolling updates, explicit
rollback, and basic monitoring. AKS is not created in this milestone.
