#!/bin/bash

### fix.sh — Regenerate types, recompose supergraph, and restart/rebuild services
###
### Usage:
###   fix              Generate types + restart services
###   fix build        Generate types + rebuild Docker images
###   fix full         npm install + generate types + rebuild Docker images
###
### Examples:
###   fix              # Quick fix: regenerate + restart
###   fix build        # Regenerate + rebuild images
###   fix full         # Full recovery: npm install + regenerate + rebuild

DEV_CMD="/Users/philip/.config/dev/dev.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# --- Argument parsing ---

mode="${1:-}"
case "$mode" in
  build|full|"") ;;
  *)
    echo -e "${RED}Error:${NC} Unknown subcommand '$mode'"
    echo "Usage: fix [build|full]"
    exit 1
    ;;
esac

# --- Repo root detection ---

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo -e "${RED}Error:${NC} Not inside a git repository"
  exit 1
fi

cd "$monorepo_root" || exit 1

# --- Spinner helper (from check.sh pattern) ---

failed=()

run_step() {
  local label="$1"
  shift
  local log_file
  log_file=$(mktemp)
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  # Run command in background
  eval "$@" > "$log_file" 2>&1 &
  local pid=$!

  # Show spinner
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${spin:$i:1} %s" "$label"
    i=$(( (i + 1) % ${#spin} ))
    sleep 0.1
  done
  wait "$pid"
  local exit_code=$?
  printf "\r\033[K"

  if [[ $exit_code -ne 0 ]]; then
    echo -e "  ${RED}✘${NC} $label"
    cat "$log_file"
    echo ""
    rm -f "$log_file"
    return 1
  fi

  echo -e "  ${GREEN}✔${NC} $label"
  rm -f "$log_file"
  return 0
}

# --- Phase 0: npm install (full only) ---

if [[ "$mode" == "full" ]]; then
  echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Installing npm dependencies${NC}"
  for svc in services/registries services/codelist apps/registries-frontend; do
    if ! run_step "npm ci — $svc" "cd '$monorepo_root/$svc' && npm ci --loglevel=warn"; then
      failed+=("npm ci — $svc")
    fi
  done
fi

# --- Phase 1: Generate types for backend services ---

echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Generating backend types${NC}"
backend_services=(services/registries)
[[ "$mode" == "full" ]] && backend_services+=(services/codelist)
for svc in "${backend_services[@]}"; do
  if ! run_step "generate — $svc" "cd '$monorepo_root/$svc' && npm run generate"; then
    failed+=("generate — $svc")
  fi
done

# --- Phase 2: Compose supergraph ---

echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Composing supergraph${NC}"
supergraph_cmd="cd '$monorepo_root/services/apollo-router'"
if [[ -f "$monorepo_root/services/apollo-router/compose-supergraph.sh" ]]; then
  supergraph_cmd+=" && ./compose-supergraph.sh"
else
  supergraph_cmd+=" && rover supergraph compose --config supergraph.yaml > supergraph.graphql"
fi
if ! run_step "supergraph composition" "$supergraph_cmd"; then
  failed+=("supergraph composition")
fi

# --- Phase 3: Generate frontend types ---

echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Generating frontend types${NC}"
if ! run_step "generate — apps/registries-frontend" "cd '$monorepo_root/apps/registries-frontend' && npm run generate"; then
  failed+=("generate — apps/registries-frontend")
fi

# --- Phase 4: Restart or rebuild services ---

services=(registries registries-frontend)
[[ "$mode" == "full" ]] && services=(registries codelist registries-frontend)

if [[ "$mode" == "build" || "$mode" == "full" ]]; then
  echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Rebuilding services${NC}"
  for svc in "${services[@]}"; do
    if ! run_step "rebuild — $svc" "$DEV_CMD up --build $svc -d"; then
      failed+=("rebuild — $svc")
    fi
  done
else
  echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Restarting services${NC}"
  for svc in "${services[@]}"; do
    if ! run_step "restart — $svc" "$DEV_CMD restart $svc"; then
      failed+=("restart — $svc")
    fi
  done
fi

# --- Phase 5: Restart router (always) ---

echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Restarting router${NC}"
if ! run_step "restart — router" "$DEV_CMD restart router"; then
  failed+=("restart — router")
fi

# --- Summary ---

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo -e "${RED}${BOLD}Some steps failed:${NC}"
  for f in "${failed[@]}"; do
    echo -e "  ${RED}✘${NC} $f"
  done
  exit 1
fi

echo -e "${GREEN}${BOLD}✅ All fixed!${NC}"
