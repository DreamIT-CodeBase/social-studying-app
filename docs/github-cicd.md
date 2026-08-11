# GitHub CI/CD setup

The repository contains two workflows:

- `CI` validates the FastAPI backend, Next.js admin portal, and Flutter app on every pull request and every push to `main`.
- `Deploy backend to Azure` builds the backend image after its checks pass, pushes it to Azure Container Registry, and updates the API and worker Container Apps in the `staging` GitHub environment.

## 1. Protect `main`

In GitHub, open **Settings > Branches > Add branch protection rule** for `main`. Require a pull request and require the three CI checks: `Backend`, `Admin portal`, and `Flutter`.

## 2. Create the staging environment

Open **Settings > Environments > New environment**, name it `staging`, and optionally add required reviewers. Add these environment variables (not secrets):

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Application/client ID of the deployment identity |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `ACR_NAME` | Azure Container Registry name, without `.azurecr.io` |
| `AZURE_RESOURCE_GROUP` | Staging resource group |
| `AZURE_API_APP` | API Container App name |
| `AZURE_DOCUMENT_WORKER_APP` | Document-ingestion worker name |
| `AZURE_TOPIC_WORKER_APP` | Topic worker name |
| `AZURE_CHUNKER_APP` | Chunker worker name |
| `AZURE_VECTORIZER_APP` | Vectorizer worker name |

The worker variables may be empty if that worker has not been provisioned.

## 3. Configure passwordless Azure authentication

Create or reuse a Microsoft Entra application/service principal. Add a federated identity credential whose GitHub subject is:

```text
repo:DreamIT-CodeBase/social-studying-app:environment:staging
```

Set the issuer to `https://token.actions.githubusercontent.com` and audience to `api://AzureADTokenExchange`. Give the identity only the roles it needs:

- `AcrPush` on the staging Azure Container Registry.
- `Contributor` on the staging Container Apps resource group (this can be narrowed to the individual Container Apps later).

OIDC issues short-lived credentials, so no Azure client secret is stored in GitHub.

## 4. Run it

Push a branch and open a pull request to exercise CI. After merging a backend change to `main`, staging deploys automatically. You can also run **Actions > Deploy backend to Azure > Run workflow** manually.

Production should use a separate `production` environment, Azure identity, resource variables, required reviewers, and a workflow triggered by a release tag. Do not point the staging workflow at production resources.
