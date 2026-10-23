# Pipeline-managed Azure infrastructure

Routine deployments run in Azure DevOps using workload identity federation.
There is no personal user ID, interactive `az login`, or manual approval in the
pipeline. Push changes to `main`; successful validation/tests and image building
are followed by Bicep infrastructure deployment and image publishing.
Pull requests and other branches do not run Azure deployment tasks.

## Identities and permissions

| Service connection | Identity | Permissions |
| --- | --- | --- |
| `sc-aks-delivery-infra` | `id-aks-delivery-infra` | Contributor and Role Based Access Control Administrator on this project's resource group; AKS RBAC Cluster Admin on this cluster |
| `sc-aks-delivery-acr` | `id-aks-delivery-acr-push` | AcrPush on this registry |
| No service connection | AKS kubelet identity | AcrPull on this registry |

The infrastructure identity can manage resources and assign roles within
`rg-aks-delivery-bicep-dev`. It has no subscription-wide role. Treat changes to
pipeline YAML and Bicep on `main` as privileged changes. Neither connection stores
client secrets; each is authorized only for this project's pipeline.
AKS local admin accounts remain disabled; Kubernetes access is assigned to the
pipeline's service principal, not to a personal user.

## Files

- `bootstrap.bicep` creates the resource group and deployment identity once.
- `deployment-identity.bicep` defines its scoped permissions and federation trust.
- `main.bicep` deploys resources within the existing project resource group.
- `dev.bicepparam` contains TEST settings and public identity/federation IDs.
- `registry.bicep` creates Basic ACR, its publishing identity, and AcrPush.
- `aks.bicep` creates AKS, kubelet AcrPull, and pipeline Kubernetes access.

The current environment uses ACR `acrx6riohznx6ove` in North Europe and AKS
`aks-delivery-bicep-dev` in Sweden Central. North Europe rejected the selected
node sizes; Sweden Central passed validation. AKS uses two AMD64
`Standard_D4s_v6` nodes and Entra Azure RBAC. The Free control-plane tier does not
make nodes, disks, networking, ACR, or cross-region transfer free.
Two nodes use 8 vCPUs; the current 10-vCPU regional quota must increase to at least
12 for the configured one-node upgrade surge.

## One-time trust bootstrap

An already authorized Azure account must establish a pipeline's first identity
and permissions; a pipeline cannot grant itself its initial access. This setup
has been performed for TEST. It is not part of routine deployments.

For a new environment, an administrator applies `bootstrap.bicep`, creates an
Azure Resource Manager service connection named `sc-aks-delivery-infra` using the
managed identity's client ID and workload identity federation, then adds the exact
issuer/subject returned by Azure DevOps to the identity through Bicep. Use the
same process for the ACR publishing connection. No identity names or IDs should
be copied to the later Terraform implementation; it must use separate resources.

Only bootstrap requires subscription-level permission to create the group.
The pipeline uses `az deployment group create --parameters infra/dev.bicepparam`
against the dedicated group; it does not deploy at subscription scope.
The infrastructure connection receives no approval/check requiring a person.

## Pipeline configuration and verification

The pipeline uses two non-secret variables:

| Variable | TEST value |
| --- | --- |
| `acrName` | `acrx6riohznx6ove` |
| `acrLoginServer` | `acrx6riohznx6ove.azurecr.io` |

After committing and pushing the changes, verify **Deploy Azure infrastructure
with federated authentication** and **Push image to ACR** pass on `main`.
Every image is tagged with the build ID. ACR login uses the supplied server
rather than a registry-details query that AcrPush cannot authorize.
The application deployment to AKS is a separate next milestone; publishing an
image does not yet update Kubernetes workloads.

Bicep compilation validates syntax, not live permissions. Only a successful hosted
run proves the infrastructure connection can deploy without personal credentials.
Role assignments can take several minutes to propagate. Removing a role resource
from an incremental Bicep deployment does not remove an existing Azure assignment.
A prior personal admin assignment, if present, is not a pipeline dependency.

## Cleanup

Disable the pipeline before teardown, then delete only this project's resource
group. This removes ACR images, identities, and AKS with its managed node group:

```sh
az resource list --resource-group rg-aks-delivery-bicep-dev --output table
az group delete --name rg-aks-delivery-bicep-dev
```

The delete command asks for confirmation. Remove both service connections and
pipeline variables afterward. To pause AKS compute instead of deleting it:

```sh
az aks stop --resource-group rg-aks-delivery-bicep-dev --name aks-delivery-bicep-dev
```

Disks, networking, and ACR can still incur charges while AKS is stopped. Stopping
or deleting resources is separate from automatic routine deployment.

References: [federated service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/automate-service-connections),
[AKS Azure RBAC](https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac).
