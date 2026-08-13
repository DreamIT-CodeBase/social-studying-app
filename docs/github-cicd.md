# GitHub CI/CD setup

The repository contains three workflows:

- `CI` validates the FastAPI backend, Next.js admin portal, and Flutter app on every pull request and every push to `main`.
- `Deploy backend to Azure` builds the backend image after its checks pass, pushes it to Azure Container Registry, and updates the API and worker Container Apps in the `staging` GitHub environment.
- `Deploy iOS apps` creates signed student and admin IPAs and can upload both to TestFlight.

## Student and admin iOS TestFlight deployment

The two-app deployment runs for pushes to `tarun/entra-auth` and can also be started manually. Add these repository Actions secrets under **Settings > Secrets and variables > Actions**:

| Secret | Value |
| --- | --- |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store profile for `ai.socialstudying.app` |
| `IOS_ADMIN_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store profile for `ai.socialstudying.app.admin` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Complete contents of the API key `.p8` file |

Every push to `tarun/entra-auth` builds and uploads both apps from that branch to TestFlight. Once the workflow exists on the default branch, it can also be started under **Actions > Deploy iOS apps > Run workflow**; leave **Upload the signed IPAs to TestFlight** enabled to deploy, or disable it to retain only the artifacts. The iOS build number is `10000` plus GitHub's run number, keeping it monotonically increasing and clear of early local builds.

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
