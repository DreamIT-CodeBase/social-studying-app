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
  info "  - Mode:        ${MODE:-full (infra + image)}"
  info "  - Environment: $ENV"
  info "  - Params file: $PARAMS_FILE"
  info "  - Bicep file:  $BICEP_FILE"

  command -v az      >/dev/null 2>&1 || error "Azure CLI not found. Install: https://aka.ms/installazurecli"
  command -v docker  >/dev/null 2>&1 || { [[ "$MODE" == "--infra-only" || "$MODE" == "--validate" ]] || error "Docker not found — required for image build."; }
  command -v jq      >/dev/null 2>&1 || error "jq not found. Install: brew install jq / apt-get install jq"
  info "  - az, jq, docker available"

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
  info "  - Subscription: $sub_name ($sub_id)"

  local resource_location
  resource_location=$(jq -r '.parameters.location.value // ""' "$PARAMS_FILE")
  info "  - Sub-deployment region: $LOCATION (deployment metadata only)"
  info "  - Resource region:       ${resource_location:-(not set in params)}"

  if [[ "$ENV" == "prod" ]]; then
    warn "Deploying to PRODUCTION. Press Ctrl-C within 5 seconds to abort..."
    sleep 5
  fi

  success "Pre-flight checks passed"
}

# ── Inject deployer object ID ─────────────────────────────────────────────────

inject_deployer_id() {
  info "Resolving deployer object ID for Key Vault role assignment..."
  local deployer_id
  deployer_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || \
                az account show --query "user.name" -o tsv)

  # If it's a service principal (CI), get the SP object ID
  if [[ "$deployer_id" == *"@"* ]]; then
    deployer_id=$(az ad sp show --id "$deployer_id" --query id -o tsv 2>/dev/null || echo "$deployer_id")
  fi

  info "  - Deployer object ID: $deployer_id"

  # Inject into params file if placeholder is still there
  local tmp
  tmp=$(mktemp)
  jq --arg id "$deployer_id" \
     '.parameters.deployerObjectId.value = $id' \
     "$PARAMS_FILE" > "$tmp"
  mv "$tmp" "$PARAMS_FILE"
  info "  - Patched $PARAMS_FILE with deployer object ID"
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

# ── Infrastructure deployment ─────────────────────────────────────────────────

deploy_infra() {
  info "Deploying infrastructure to environment: $ENV"
  inject_deployer_id

  local deployment_name="social-study-app-$ENV-$(date +%Y%m%d%H%M%S)"
  info "Deployment name: $deployment_name"
  info "Submitting deployment to Azure (async — script will then poll status)..."

  # --no-wait returns immediately with the deployment queued. We then poll with
  # watch_deployment(), which prints a per-resource status table every 30s.
  # This replaces the old --output table flow that hung silently on Windows /
  # Git Bash when the streaming connection dropped.
  az deployment sub create \
    --name "$deployment_name" \
    --location "$LOCATION" \
    --template-file "$BICEP_FILE" \
    --parameters "@$PARAMS_FILE" \
    --no-wait \
    --output none

  success "Deployment submitted. Watch via:"
  info "  az deployment sub show --name $deployment_name --query properties.provisioningState -o tsv"
  echo ""

  watch_deployment "$deployment_name"

  local final_state
  final_state=$(az deployment sub show --name "$deployment_name" \
                  --query properties.provisioningState -o tsv 2>/dev/null || echo "Unknown")

  if [[ "$final_state" != "Succeeded" ]]; then
    warn "Deployment ended with state: $final_state"
    warn "Failed resources:"
    az deployment operation sub list --name "$deployment_name" \
      --query "[?properties.provisioningState=='Failed'].{module:properties.targetResource.resourceName, error:properties.statusMessage.error.message}" \
      -o table || true
    error "Deployment did not succeed. See above."
  fi

  success "Infrastructure deployment complete: $deployment_name"

  # Extract outputs and write backend .env
  extract_outputs "$deployment_name"
}

# ── Deployment watcher ────────────────────────────────────────────────────────
#
# Polls the sub-scope deployment every POLL_INTERVAL seconds and prints:
#   1. Overall provisioning state of the sub-deployment
#   2. Per-module status table (Succeeded / Running / Failed counts)
#   3. Names of modules currently provisioning, with elapsed time
#
# Exits when the deployment reaches Succeeded / Failed / Canceled.

watch_deployment() {
  local deployment_name="$1"
  local poll_interval="${POLL_INTERVAL:-30}"
  local elapsed=0
  local iteration=0

  info "Polling every ${poll_interval}s. Press Ctrl-C to stop watching (deployment continues in Azure)."
  echo ""

  while true; do
    iteration=$((iteration + 1))
    local state
    state=$(az deployment sub show --name "$deployment_name" \
              --query properties.provisioningState -o tsv 2>/dev/null || echo "Unknown")

    echo -e "${CYAN}── poll #${iteration}  (+${elapsed}s)  overall: ${state} ──${NC}"

    # Pull all module operations once, reuse for both summary and pending list
    local ops
    ops=$(az deployment operation sub list --name "$deployment_name" -o json 2>/dev/null || echo "[]")

    # Compact summary: count by state
    local summary
    summary=$(echo "$ops" | jq -r '.[].properties.provisioningState' 2>/dev/null \
              | sort | uniq -c | awk '{printf "%s=%s  ", $2, $1}')
    if [[ -n "$summary" ]]; then
      echo "  modules: $summary"
    else
      echo "  modules: (no operations reported yet)"
    fi

    # In-progress modules with their start time
    local pending
    pending=$(echo "$ops" \
              | jq -r '.[] | select(.properties.provisioningState=="Running") | "    \(.properties.targetResource.resourceName // .properties.targetResource.id // "?")  (started \(.properties.timestamp))"' 2>/dev/null)
    if [[ -n "$pending" ]]; then
      echo "  in progress:"
      echo "$pending"
    fi

    # Recently-failed modules surface immediately so we don't waste time waiting
    local failed
    failed=$(echo "$ops" \
              | jq -r '.[] | select(.properties.provisioningState=="Failed") | "    \(.properties.targetResource.resourceName // "?"): \(.properties.statusMessage.error.message // "(no message)")"' 2>/dev/null)
    if [[ -n "$failed" ]]; then
      warn "  FAILED modules:"
      echo "$failed"
    fi

    case "$state" in
      Succeeded|Failed|Canceled)
        echo ""
        info "Deployment reached terminal state: $state (after ${elapsed}s, ${iteration} polls)"
        return 0
        ;;
    esac

    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))
  done
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

  local api_url registry_server registry_name kv_name container_app worker_app rg_name
  api_url=$(echo "$outputs"        | jq -r '.apiUrl.value // ""')
  registry_server=$(echo "$outputs" | jq -r '.registryLoginServer.value // ""')
  registry_name=$(echo "$outputs"  | jq -r '.registryName.value // ""')
  kv_name=$(echo "$outputs"        | jq -r '.keyVaultName.value // ""')
  container_app=$(echo "$outputs"  | jq -r '.containerAppName.value // ""')
  worker_app=$(echo "$outputs"     | jq -r '.workerAppName.value // ""')
  rg_name=$(echo "$outputs"        | jq -r '.resourceGroupName.value // ""')
  info "  - Resource group: $rg_name"
  info "  - Key Vault:      $kv_name"
  info "  - Container app:  $container_app"
  info "  - Worker app:     ${worker_app:-(none — older deployment without Sprint 2.3)}"
  info "  - API URL:        $api_url"

  # Pull secrets from Key Vault to write a local .env
  info "Reading secrets from Key Vault: $kv_name"
  local cosmos_cs redis_cs sb_cs openai_key search_key cs_key storage_cs di_key
  cosmos_cs=$(az keyvault secret show   --vault-name "$kv_name" --name "cosmos-connection-string"     -o tsv --query "value" 2>/dev/null || echo "")
  redis_cs=$(az keyvault secret show    --vault-name "$kv_name" --name "redis-connection-string"      -o tsv --query "value" 2>/dev/null || echo "")
  sb_cs=$(az keyvault secret show       --vault-name "$kv_name" --name "service-bus-connection-string" -o tsv --query "value" 2>/dev/null || echo "")
  openai_key=$(az keyvault secret show  --vault-name "$kv_name" --name "azure-openai-key"             -o tsv --query "value" 2>/dev/null || echo "")
  search_key=$(az keyvault secret show  --vault-name "$kv_name" --name "ai-search-key"                -o tsv --query "value" 2>/dev/null || echo "")
  cs_key=$(az keyvault secret show      --vault-name "$kv_name" --name "content-safety-key"           -o tsv --query "value" 2>/dev/null || echo "")
  storage_cs=$(az keyvault secret show  --vault-name "$kv_name" --name "storage-connection-string"    -o tsv --query "value" 2>/dev/null || echo "")
  di_key=$(az keyvault secret show      --vault-name "$kv_name" --name "document-intelligence-key"    -o tsv --query "value" 2>/dev/null || echo "")

  # Warn on any missing secret — empty values almost always indicate the matching
  # module didn't deploy or RBAC is not yet propagated to the deployer identity.
  local missing=""
  [[ -z "$cosmos_cs"  ]] && missing+=" cosmos-connection-string"
  [[ -z "$redis_cs"   ]] && missing+=" redis-connection-string"
  [[ -z "$sb_cs"      ]] && missing+=" service-bus-connection-string"
  [[ -z "$openai_key" ]] && missing+=" azure-openai-key"
  [[ -z "$search_key" ]] && missing+=" ai-search-key"
  [[ -z "$cs_key"     ]] && missing+=" content-safety-key"
  [[ -z "$storage_cs" ]] && missing+=" storage-connection-string"
  [[ -z "$di_key"     ]] && missing+=" document-intelligence-key"
  [[ -n "$missing"    ]] && warn "Missing Key Vault secrets:$missing"

  local search_endpoint openai_endpoint storage_endpoint cs_endpoint di_endpoint
  search_endpoint=$(echo "$outputs"  | jq -r '.searchEndpoint.value // ""')
  openai_endpoint=$(echo "$outputs"  | jq -r '.openAiEndpoint.value // ""')
  storage_endpoint=$(echo "$outputs" | jq -r '.storageEndpoint.value // ""')
  cs_endpoint=$(echo "$outputs"      | jq -r '.contentSafetyEndpoint.value // ""')
  di_endpoint=$(echo "$outputs"      | jq -r '.documentIntelligenceEndpoint.value // ""')

  local env_file="$REPO_ROOT/backend/.env.$ENV"

  # Preserve any B2C / Entra External ID values already in the existing env
  # file. Bicep doesn't provision the External ID tenant (Sprint 1.5 is portal
  # work), so deploy.sh must NOT clobber values the user pasted in by hand.
  local existing_b2c_tenant_id="" existing_b2c_client_id="" existing_b2c_subdomain="" existing_b2c_policy="B2C_1_signupsignin"
  if [[ -f "$env_file" ]]; then
    existing_b2c_tenant_id=$(grep   "^B2C_TENANT_ID="        "$env_file" | cut -d= -f2- || echo "")
    existing_b2c_client_id=$(grep   "^B2C_CLIENT_ID="        "$env_file" | cut -d= -f2- || echo "")
    existing_b2c_subdomain=$(grep   "^B2C_TENANT_SUBDOMAIN=" "$env_file" | cut -d= -f2- || echo "")
    local prior_policy
    prior_policy=$(grep "^B2C_POLICY_NAME=" "$env_file" | cut -d= -f2- || echo "")
    [[ -n "$prior_policy" ]] && existing_b2c_policy="$prior_policy"
    if [[ -n "$existing_b2c_tenant_id" || -n "$existing_b2c_client_id" ]]; then
      info "  - Preserving B2C / Entra External ID values from existing $env_file"
    fi
  fi

  info "Writing $env_file..."
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
CONTENT_SAFETY_ENDPOINT=$cs_endpoint
CONTENT_SAFETY_KEY=$cs_key

# Azure Blob Storage
STORAGE_CONNECTION_STRING=$storage_cs
STORAGE_ENDPOINT=$storage_endpoint

# Azure AI Document Intelligence (Sprint 2.1)
DOCUMENT_INTELLIGENCE_ENDPOINT=$di_endpoint
DOCUMENT_INTELLIGENCE_KEY=$di_key

# Azure Service Bus
SERVICE_BUS_CONNECTION=$sb_cs

# Microsoft Entra External ID (Sprint 1.5 — portal-provisioned, preserved across deploys)
B2C_TENANT_ID=$existing_b2c_tenant_id
B2C_CLIENT_ID=$existing_b2c_client_id
B2C_TENANT_SUBDOMAIN=$existing_b2c_subdomain
B2C_POLICY_NAME=$existing_b2c_policy

# Container registry (used by push-image.sh)
ACR_LOGIN_SERVER=$registry_server
ACR_NAME=$registry_name
CONTAINER_APP_NAME=$container_app
WORKER_APP_NAME=$worker_app
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

  local registry_server registry_name container_app worker_app rg_name
  registry_server=$(grep "^ACR_LOGIN_SERVER=" "$env_file" | cut -d= -f2)
  registry_name=$(grep   "^ACR_NAME="         "$env_file" | cut -d= -f2)
  container_app=$(grep   "^CONTAINER_APP_NAME=" "$env_file" | cut -d= -f2)
  worker_app=$(grep      "^WORKER_APP_NAME="    "$env_file" | cut -d= -f2)
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

  info "Updating API Container App image to: $image_latest"
  az containerapp update \
    --name "$container_app" \
    --resource-group "$rg_name" \
    --image "$image_latest" \
    --output table

  # Worker Container App shares the same image — different process started by
  # the bicep `command/args` override (`python -m app.workers.document_ingestion`).
  if [[ -n "$worker_app" ]]; then
    info "Updating Worker Container App image to: $image_latest"
    az containerapp update \
      --name "$worker_app" \
      --resource-group "$rg_name" \
      --image "$image_latest" \
      --output table
    success "Worker app updated: $worker_app"
  else
    warn "WORKER_APP_NAME missing from $env_file — worker not redeployed."
    warn "Re-run with --infra-only after the bicep changes land to populate it."
  fi

  local api_fqdn
  api_fqdn=$(az containerapp show --name "$container_app" -g "$rg_name" \
              --query properties.configuration.ingress.fqdn -o tsv 2>/dev/null || echo "")
  success "Deploy complete. API URL: ${api_fqdn:+https://$api_fqdn}"
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
