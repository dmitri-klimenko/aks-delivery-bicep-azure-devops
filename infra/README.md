# ACR and federated Azure DevOps authentication

This milestone creates only a dedicated resource group, Basic Azure Container
Registry, a user-assigned managed identity, and its registry-scoped `AcrPush` role.
The optional federated credential trusts one Azure DevOps service connection.
No client secrets, registry admin credentials, AKS, or deployment pipeline are used.
The public registry endpoint supports hosted agents; anonymous pulls are disabled.
Basic ACR is billable while it exists.

Use a current Azure CLI with Bicep. Run from the repository root. Your signed-in
bootstrap user needs permission to create the resource group and resources, and
to assign roles (for example Owner, or Contributor plus Role Based Access Control
Administrator). The pipeline identity receives only `AcrPush` on this registry;
it cannot deploy infrastructure. Infrastructure is applied locally for now.

## 1. Bootstrap Azure resources

The current TEST environment has already been bootstrapped in North Europe.
Its service connection is `sc-aks-delivery-acr`, and its registry is
`acrx6riohznx6ove`. `dev.bicepparam` records the public federation identifiers
for this deployment. To update this existing environment, use:

```sh
az deployment sub what-if --name aks-delivery-acr --location northeurope --parameters infra/dev.bicepparam
az deployment sub create --name aks-delivery-acr --location northeurope --parameters infra/dev.bicepparam
```

Select the TEST subscription first. These commands preserve the federation trust.
The bootstrap steps below describe creating a new environment; use new federation
values when connecting a different Azure DevOps project or managed identity.

```sh
az login
export AZURE_SUBSCRIPTION_ID='<your TEST subscription ID>'
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
az account show --query '{name:name,id:id}' --output table
az bicep build --file infra/main.bicep --outfile /tmp/aks-delivery-main.json
az deployment sub what-if --name aks-delivery-acr --location northeurope --template-file infra/main.bicep
az deployment sub create --name aks-delivery-acr --location northeurope --template-file infra/main.bicep
az deployment sub show --name aks-delivery-acr --query properties.outputs --output json
```

Defaults: `rg-aks-delivery-bicep-dev`, North Europe, and a deterministic ACR name
derived from the resource group ID. Set `--parameters location=...` when deploying
elsewhere. These resources belong exclusively to Bicep + Azure DevOps; use a
different resource group, registry, and identity for the later Terraform project.
North Europe passed the deployment preview in the selected TEST subscription;
West Europe was rejected by Azure for this subscription.

The initial deployment does not create a federated credential. For subsequent
deployments after federation is configured, always supply both federation values
as in step 3. Do not change the deployment name or group unintentionally.

## 2. Create the Azure DevOps service connection

In **Project settings > Service connections > New service connection**, select
**Azure Resource Manager**, **App registration or Managed identity (manual)**,
and **Workload identity federation**. Use:

| Field | Value |
| --- | --- |
| Service connection name | `sc-aks-delivery-acr` |
| Environment | Azure Cloud |
| Directory (tenant) ID | `tenantId` from deployment outputs |
| Scope level | Subscription |
| Subscription ID | `subscriptionId` from deployment outputs |
| Subscription name | Your selected TEST subscription name |
| Application (client) ID | `identityClientId` from deployment outputs |

Keep the connection as a draft. Copy the generated **Issuer** and **Subject
identifier** exactly; do not derive them from organization/project names.
Leave **Grant access permission to all pipelines** unchecked.

## 3. Add the federation trust through Bicep

In the same terminal used for bootstrap:

```sh
export ADO_FEDERATED_ISSUER='<issuer from the draft service connection>'
export ADO_FEDERATED_SUBJECT='<subject identifier from the draft service connection>'
az deployment sub what-if --name aks-delivery-acr --location northeurope --template-file infra/main.bicep \
  --parameters federatedIssuer="$ADO_FEDERATED_ISSUER" federatedSubject="$ADO_FEDERATED_SUBJECT"
az deployment sub create --name aks-delivery-acr --location northeurope --template-file infra/main.bicep \
  --parameters federatedIssuer="$ADO_FEDERATED_ISSUER" federatedSubject="$ADO_FEDERATED_SUBJECT"
```

Return to Azure DevOps and **Finish setup > Verify and save**. Authorize only this
pipeline through the connection's pipeline permissions. Role assignments and
federation can take a few minutes to propagate.

## 4. Enable image publishing

In the pipeline's **Edit > Variables**, add two non-secret variables:

| Variable | Deployment output | Current TEST value |
| --- | --- | --- |
| `acrName` | `registryName` | `acrx6riohznx6ove` |
| `acrLoginServer` | `loginServer` | `acrx6riohznx6ove.azurecr.io` |

Use the deployment output for the login server rather than querying it inside
the pipeline: `AcrPush` does not grant management-plane registry read access.
Commit and push the repository changes when ready.

Select **Run pipeline** on `main` and check **Push main-branch image to ACR**.
The parameter defaults to false so existing CI can run during bootstrap. After
the first successful push, change `pushImage`'s default to `true` in
`azure-pipelines.yml` and commit it to enable automatic publishing for main.
PR and non-main builds omit the Azure task even when the parameter is true.

The AzureCLI task exchanges the service connection's federated identity for Azure
access, logs Docker into ACR, and pushes `aks-delivery:<Build.BuildId>`.
Every run uses a different tag; there is no `latest` tag. The tag is not locked
against overwrites. Record the image digest from the push output for deployment.

## 5. Verify the hosted push

Check the pipeline's tests and push step. From your local terminal, with an
account permitted to read registry repositories:

```sh
export ACR_NAME=$(az deployment sub show --name aks-delivery-acr --query properties.outputs.registryName.value --output tsv)
az acr repository show-tags --name "$ACR_NAME" --repository aks-delivery --output table
```

The list should contain the successful run's build ID. An operator with only
management-plane Contributor permissions may need separate `AcrPull` access to
list repository contents; the pipeline's identity already has `AcrPush`.
Only a successful Azure DevOps run verifies the federated login and image push.

If publishing fails, check the service connection name/authorization, `acrName`,
issuer/subject, and the identity's registry role. This registry explicitly uses
RBAC registry permissions: `AcrPush` does not apply to ABAC repository mode.

## Cleanup

When finished, disable image publishing (`pushImage: false` by default), then
inspect and delete only this project's resource group. This deletes stored images
and the managed identity, including its federated credential:

```sh
az resource list --resource-group rg-aks-delivery-bicep-dev --output table
az group delete --name rg-aks-delivery-bicep-dev
```

The delete command asks for confirmation. Also remove `sc-aks-delivery-acr` and
the `acrName` and `acrLoginServer` pipeline variables in Azure DevOps. Subscription deployment history
is separate from the group and can optionally be removed:

```sh
az deployment sub delete --name aks-delivery-acr
```

References: [manual federated service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity),
[ACR registry schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.containerregistry/2025-11-01/registries),
[ACR permission modes](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-rbac-abac-repository-permissions).
