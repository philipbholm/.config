#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -x "$HOME/.config/dev/link-claude-context.sh" ]; then
    "$HOME/.config/dev/link-claude-context.sh" "$SCRIPT_DIR"
fi

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

SERVICES=(apps/main-frontend services/codelist services/registries services/admin)

# ------------------------------------------------------------------
# 1. npm install for each service
# ------------------------------------------------------------------
step "Installing npm dependencies"

for svc in "${SERVICES[@]}"; do
    echo "  $svc ..."
    (cd "$SCRIPT_DIR/$svc" && npm ci --loglevel=warn) || fail "npm ci failed in $svc"
done

# ------------------------------------------------------------------
# 2. Generate types for backend services
# ------------------------------------------------------------------
step "Generating types for backend services"

for svc in services/codelist services/registries services/admin; do
    echo "  $svc ..."
    (cd "$SCRIPT_DIR/$svc" && npm run generate) || fail "generate failed in $svc"
done

# ------------------------------------------------------------------
# 3. Compose Apollo Router supergraph
# ------------------------------------------------------------------
step "Composing Apollo Router supergraph"

(cd "$SCRIPT_DIR/services/apollo-router" && ./compose-supergraph.sh) || fail "supergraph composition failed"

# ------------------------------------------------------------------
# 4. Generate frontend GraphQL types (needs supergraph + service schemas)
# ------------------------------------------------------------------
step "Generating frontend types"

(cd "$SCRIPT_DIR/apps/main-frontend" && npm run generate) || fail "frontend generate failed"

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}Worktree setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  docker compose up -d          # Start all containers"
echo "  rebuild frontend registries   # Rebuild specific services"
