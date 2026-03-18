#!/bin/bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: Not inside a git repository"
    exit 1
}
cd "$REPO_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

step() {
    echo ""
    echo -e "${GREEN}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

fail() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

# Check GITHUB_TOKEN is available (needed for @ledidi-as scoped packages)
if [ -z "$GITHUB_TOKEN" ]; then
    warn "GITHUB_TOKEN is not set. npm install may fail for @ledidi-as scoped packages."
    echo "  Set it with: export GITHUB_TOKEN=<your-token>"
fi

SERVICES=(apps/registries-frontend services/codelist services/registries)

# ------------------------------------------------------------------
# 1. npm install for each service
# ------------------------------------------------------------------
step "Installing npm dependencies"

for svc in "${SERVICES[@]}"; do
    echo "  $svc ..."
    (cd "$REPO_ROOT/$svc" && npm ci --loglevel=warn) || fail "npm ci failed in $svc"
done

# ------------------------------------------------------------------
# 2. Generate types for backend services
# ------------------------------------------------------------------
step "Generating types for backend services"

for svc in services/codelist services/registries; do
    echo "  $svc ..."
    (cd "$REPO_ROOT/$svc" && npm run generate) || fail "generate failed in $svc"
done

# ------------------------------------------------------------------
# 3. Compose Apollo Router supergraph
# ------------------------------------------------------------------
step "Composing Apollo Router supergraph"

(cd "$REPO_ROOT/services/apollo-router" && ./compose-supergraph.sh) || fail "supergraph composition failed"

# ------------------------------------------------------------------
# 4. Generate frontend GraphQL types (needs supergraph + service schemas)
# ------------------------------------------------------------------
step "Generating frontend types"

(cd "$REPO_ROOT/apps/registries-frontend" && npm run generate) || fail "frontend generate failed"

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}Stack setup complete.${NC}"
