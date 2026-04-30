#!/usr/bin/env bash
# Usage: ./scripts/deploy.sh <env>
# Example: ./scripts/deploy.sh dev

set -euo pipefail

ENV=${1:-dev}
LOCATION="eastus"

echo "Deploying Social Study App infrastructure to: $ENV"

az deployment sub create \
  --name "social-study-app-$ENV-$(date +%Y%m%d%H%M%S)" \
  --location "$LOCATION" \
  --template-file bicep/main.bicep \
  --parameters "@environments/$ENV/params.json"

echo "Deployment complete for environment: $ENV"
