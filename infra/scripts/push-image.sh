#!/usr/bin/env bash
# Standalone image build & push — wraps the --app-only mode of deploy.sh.
# Use this when you only want to update the running API without re-deploying infra.
#
# Usage: ./scripts/push-image.sh <env>

set -euo pipefail

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/deploy.sh" "$ENV" --app-only
