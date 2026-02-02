#!/bin/bash
set -euo pipefail

export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

project_name="$(basename "$(git rev-parse --show-toplevel)")"

if [[ $# -eq 0 || -z "$1" ]]; then
  echo "Usage: shell <service>"
  echo "Services: frontend, registries, studies, admin, codelist, auth"
  exit 1
fi

service="$1"

case "$service" in
  frontend) container_name="${project_name}-main-frontend-1" ;;
  *)        container_name="${project_name}-$service-1" ;;
esac

docker exec -it "$container_name" /bin/sh
