#!/usr/bin/env bash
# Social Study App — Azure infrastructure deployment
#
# Usage:
#   ./scripts/deploy.sh <env> [--infra-only | --app-only | --validate]
#
# Examples:
#   ./scripts/deploy.sh dev               # deploy infra + build & push app image
#   ./scripts/deploy.sh dev --infra-only  # provision Azure resources only
#   ./scripts/deploy.sh dev --app-only    # build & push image, update container app
#   ./scripts/deploy.sh dev --validate    # validate Bicep without deploying
#   ./scripts/deploy.sh prod              # full production deployment

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────────

ENV=${1:-dev}
MODE=${2:-""}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$INFRA_DIR/.." && pwd)"
PARAMS_FILE="$INFRA_DIR/environments/$ENV/params.json"
BICEP_FILE="$INFRA_DIR/bicep/main.bicep"
DOCKERFILE="$REPO_ROOT/backend/Dockerfile"
LOCATION="eastus"

# ── Colours ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────

preflight() {
  info "Running pre-flight checks..."

  command -v az      >/dev/null 2>&1 || error "Azure CLI not found. Install: https://aka.ms/installazurecli"
  command -v docker  >/dev/null 2>&1 || { [[ "$MODE" == "--infra-only" || "$MODE" == "--validate" ]] || error "Docker not found — required for image build."; }
  command -v jq      >/dev/null 2>&1 || error "jq not found. Install: brew install jq / apt-get install jq"

  [[ -f "$PARAMS_FILE" ]]  || error "Params file not found: $PARAMS_FILE"
  [[ -f "$BICEP_FILE" ]]   || error "Bicep file not found: $BICEP_FILE"
  [[ -f "$DOCKERFILE" ]]   || { [[ "$MODE" == "--infra-only" || "$MODE" == "--validate" ]] || error "Dockerfile not found: $DOCKERFILE"; }

  # Verify Azure login
  local account
  account=$(az account show --query "{name:name,id:id}" -o json 2>/dev/null || echo "")
  [[ -z "$account" ]] && error "Not logged in to Azure. Run: az login"

  local sub_name sub_id
  sub_name=$(echo "$account" | jq -r '.name')
  sub_id=$(echo "$account"   | jq -r '.id')
  info "Subscription: $sub_name ($sub_id)"

  if [[ "$ENV" == "prod" ]]; then
    warn "Deploying to PRODUCTION. Press Ctrl-C within 5 seconds to abort..."
    sleep 5
  fi

  success "Pre-flight checks passed"
}

# ── Inject deployer object ID ─────────────────────────────────────────────────

inject_deployer_id() {
  local deployer_id
  deployer_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || \
                az account show --query "user.name" -o tsv)

  # If it's a service principal (CI), get the SP object ID
  if [[ "$deployer_id" == *"@"* ]]; then
    deployer_id=$(az ad sp show --id "$deployer_id" --query id -o tsv 2>/dev/null || echo "$deployer_id")
  fi

  info "Deployer object ID: $deployer_id"

  # Inject into params file if placeholder is still there
  local tmp
  tmp=$(mktemp)
  jq --arg id "$deployer_id" \
     '.parameters.deployerObjectId.value = $id' \
     "$PARAMS_FILE" > "$tmp"
  mv "$tmp" "$PARAMS_FILE"
}

# ── Bicep validation ──────────────────────────────────────────────────────────

validate() {
  info "Validating Bicep template..."
  inject_deployer_id

  az deployment sub validate \
    --location "$LOCATION" \
    --template-file "$BICEP_FILE" \
    --parameters "@$PARAMS_FILE" \
    --output table

  success "Bicep validation passed"
}

# ── Purge soft-deleted Key Vaults ────────────────────────────────────────────
# Key Vault soft-delete keeps names reserved for 7 days after RG deletion.
# uniqueString(resourceGroup().id) produces the same name on redeploy, so
# we purge any matching deleted vault before deploying to avoid VaultAlreadyExists.

purge_deleted_key_vaults() {
  local location="$1"
  info "Checking for soft-deleted Key Vaults matching 'kv-ssa-${ENV}-*'..."

  local deleted_vaults
  deleted_vaults=$(az keyvault list-deleted \
    --query "[?starts_with(name, 'kv-ssa-${ENV}-')].name" \
    -o tsv 2>/dev/null || echo "")

  if [[ -z "$deleted_vaults" ]]; then
    return 0
  fi

  while IFS= read -r vault_name; do
    [[ -z "$vault_name" ]] && continue
    warn "Purging soft-deleted Key Vault: $vault_name"
    az keyvault purge --name "$vault_name" --location "$location"
    success "Purged: $vault_name"
  done <<< "$deleted_vaults"
}

# ── Infrastructure deployment ─────────────────────────────────────────────────

deploy_infra() {
  info "Deploying infrastructure to environment: $ENV"
  inject_deployer_id

  # Resolve location from params file for the purge step
  local deploy_location
  deploy_location=$(jq -r '.parameters.location.value // "eastus"' "$PARAMS_FILE")
  purge_deleted_key_vaults "$deploy_location"

  local deployment_name="social-study-app-$ENV-$(date +%Y%m%d%H%M%S)"

  az deployment sub create \
    --name "$deployment_name" \
    --location "$LOCATION" \
    --template-file "$BICEP_FILE" \
    --parameters "@$PARAMS_FILE" \
    --output table

  success "Infrastructure deployment complete: $deployment_name"

  # Extract outputs and write backend .env
  extract_outputs "$deployment_name"
}

# ── Extract outputs → write .env ──────────────────────────────────────────────

extract_outputs() {
  local deployment_name="$1"
  info "Extracting deployment outputs..."

  local outputs
  outputs=$(az deployment sub show \
    --name "$deployment_name" \
    --query "properties.outputs" \
    -o json)

  local api_url registry_server registry_name kv_name container_app rg_name
  api_url=$(echo "$outputs"        | jq -r '.apiUrl.value // ""')
  registry_server=$(echo "$outputs" | jq -r '.registryLoginServer.value // ""')
  registry_name=$(echo "$outputs"  | jq -r '.registryName.value // ""')
  kv_name=$(echo "$outputs"        | jq -r '.keyVaultName.value // ""')
  container_app=$(echo "$outputs"  | jq -r '.containerAppName.value // ""')
  rg_name=$(echo "$outputs"        | jq -r '.resourceGroupName.value // ""')

  # Pull secrets from Key Vault to write a local .env
  info "Reading secrets from Key Vault: $kv_name"
  local cosmos_cs redis_cs sb_cs openai_key search_key cs_key storage_cs
  cosmos_cs=$(az keyvault secret show   --vault-name "$kv_name" --name "cosmos-connection-string"  -o tsv --query "value" 2>/dev/null || echo "")
  redis_cs=$(az keyvault secret show    --vault-name "$kv_name" --name "redis-connection-string"   -o tsv --query "value" 2>/dev/null || echo "")
  sb_cs=$(az keyvault secret show       --vault-name "$kv_name" --name "service-bus-connection-string" -o tsv --query "value" 2>/dev/null || echo "")
  openai_key=$(az keyvault secret show  --vault-name "$kv_name" --name "azure-openai-key"          -o tsv --query "value" 2>/dev/null || echo "")
  search_key=$(az keyvault secret show  --vault-name "$kv_name" --name "ai-search-key"             -o tsv --query "value" 2>/dev/null || echo "")
  cs_key=$(az keyvault secret show      --vault-name "$kv_name" --name "content-safety-key"        -o tsv --query "value" 2>/dev/null || echo "")
  storage_cs=$(az keyvault secret show  --vault-name "$kv_name" --name "storage-connection-string" -o tsv --query "value" 2>/dev/null || echo "")

  local search_endpoint openai_endpoint storage_endpoint content_safety_endpoint
  search_endpoint=$(echo "$outputs"         | jq -r '.searchEndpoint.value // ""')
  openai_endpoint=$(echo "$outputs"         | jq -r '.openAiEndpoint.value // ""')
  storage_endpoint=$(echo "$outputs"        | jq -r '.storageEndpoint.value // ""')

  local env_file="$REPO_ROOT/backend/.env.$ENV"
  cat > "$env_file" <<EOF
# Auto-generated by deploy.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Environment: $ENV
ENVIRONMENT=$ENV

# Azure Cosmos DB (MongoDB API)
COSMOS_CONNECTION_STRING=$cosmos_cs

# Azure Cache for Redis
REDIS_URL=$redis_cs

# Azure AI Search
SEARCH_ENDPOINT=$search_endpoint
SEARCH_KEY=$search_key

# Azure OpenAI (AI Foundry)
AZURE_OPENAI_ENDPOINT=$openai_endpoint
AZURE_OPENAI_KEY=$openai_key
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Azure Content Safety
CONTENT_SAFETY_ENDPOINT=$(echo "$outputs" | jq -r '.contentSafetyEndpoint.value // ""' 2>/dev/null || echo "")
CONTENT_SAFETY_KEY=$cs_key

# Azure Blob Storage
STORAGE_CONNECTION_STRING=$storage_cs
STORAGE_ENDPOINT=$storage_endpoint

# Azure Service Bus
SERVICE_BUS_CONNECTION=$sb_cs

# Azure AD B2C — fill in after provisioning B2C (Task 1.5)
B2C_TENANT_ID=
B2C_CLIENT_ID=
B2C_POLICY_NAME=B2C_1_signupsignin

# Container registry (used by push-image.sh)
ACR_LOGIN_SERVER=$registry_server
ACR_NAME=$registry_name
CONTAINER_APP_NAME=$container_app
RESOURCE_GROUP=$rg_name
EOF

  success "Environment file written: $env_file"

  echo ""
  echo -e "${GREEN}════════════════════════════════════════${NC}"
  echo -e "${GREEN} Deployment summary — $ENV${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"
  echo -e "  API URL:        ${CYAN}$api_url${NC}"
  echo -e "  ACR:            $registry_server"
  echo -e "  Key Vault:      $kv_name"
  echo -e "  Env file:       $env_file"
  echo ""
  echo -e "  Next steps:"
  echo -e "  1. Provision Azure AD B2C (Task 1.5) and add IDs to $env_file"
  echo -e "  2. Run: ${CYAN}./scripts/push-image.sh $ENV${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"
}

# ── Build & push Docker image ─────────────────────────────────────────────────

push_image() {
  local env_file="$REPO_ROOT/backend/.env.$ENV"
  [[ -f "$env_file" ]] || error "Env file not found: $env_file  Run --infra-only first."

  local registry_server registry_name container_app rg_name
  registry_server=$(grep "^ACR_LOGIN_SERVER=" "$env_file" | cut -d= -f2)
  registry_name=$(grep   "^ACR_NAME="         "$env_file" | cut -d= -f2)
  container_app=$(grep   "^CONTAINER_APP_NAME=" "$env_file" | cut -d= -f2)
  rg_name=$(grep         "^RESOURCE_GROUP="   "$env_file" | cut -d= -f2)

  [[ -z "$registry_server" ]] && error "ACR_LOGIN_SERVER missing from $env_file"

  local image_tag="$registry_server/social-study-api:$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
  local image_latest="$registry_server/social-study-api:latest"

  info "Logging in to ACR: $registry_server"
  az acr login --name "$registry_name"

  info "Building image: $image_tag"
  docker build \
    --platform linux/amd64 \
    --tag "$image_tag" \
    --tag "$image_latest" \
    "$REPO_ROOT/backend"

  info "Pushing image..."
  docker push "$image_tag"
  docker push "$image_latest"
  success "Image pushed: $image_tag"

  info "Updating Container App image to: $image_latest"
  az containerapp update \
    --name "$container_app" \
    --resource-group "$rg_name" \
    --image "$image_latest" \
    --output table

  success "Container App updated. API is live at: $(grep '^# API URL' "$env_file" || echo "(see Azure portal)")"
}

# ── Entry point ───────────────────────────────────────────────────────────────

preflight

case "$MODE" in
  --validate)
    validate
    ;;
  --infra-only)
    deploy_infra
    ;;
  --app-only)
    push_image
    ;;
  "")
    deploy_infra
    push_image
    ;;
  *)
    error "Unknown mode: $MODE. Use --infra-only, --app-only, or --validate"
    ;;
esac
