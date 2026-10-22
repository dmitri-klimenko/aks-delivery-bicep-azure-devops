# aks-delivery-bicep-azure-devops
Milestone 1: a small ASP.NET Core API, integration tests, and a container using
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

## Next milestone

Add a small Azure DevOps CI pipeline that checks out GitHub source, runs tests,
and builds the image. Later milestones add Bicep, federated Azure authentication,
ACR/AKS, probes, rolling updates, explicit rollback, monitoring, and cleanup.
No Azure resources or pipelines are created yet. The later Terraform + GitHub
Actions implementation must manage separate Azure resources.
