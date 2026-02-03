#!/bin/bash
set -euo pipefail

[[ -d "/Applications/Docker.app/Contents/Resources/bin" ]] && \
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker not installed" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: Docker daemon not running" >&2
        exit 1
    fi
}

function check_container() {
    local container_name="$1"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "Error: Container '$container_name' is not running" >&2
        exit 1
    fi
}

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
project_name="$(basename "$(git rev-parse --show-toplevel)")"

check_docker

if [[ $# -eq 0 || -z "$1" ]]; then
  echo "Usage: shell <service>"
  echo "Services: frontend, registries, studies, admin, codelist, auth"
  exit 1
fi

service="$1"

case "$service" in
  frontend)   container_name="${project_name}-main-frontend-1" ;;
  registries|studies|admin|codelist|auth)
              container_name="${project_name}-$service-1" ;;
  *)
    echo "Error: Unknown service '$service'" >&2
    echo "Valid services: frontend, registries, studies, admin, codelist, auth" >&2
    exit 1
    ;;
esac

check_container "$container_name"
docker exec -it "$container_name" /bin/sh
