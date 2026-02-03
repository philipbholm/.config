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
  echo "Usage: db <service>"
  echo "Services: admin, studies, codelist, registries"
  exit 1
fi

service="$1"

case "$service" in
  admin)
    check_container "${project_name}-mysql-1"
    docker exec -it "${project_name}-mysql-1" mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root}" prjcts
    ;;
  studies)
    check_container "${project_name}-postgres-1"
    docker exec -it "${project_name}-postgres-1" psql -U postgres -d studies
    ;;
  codelist)
    check_container "${project_name}-postgres-1"
    docker exec -it "${project_name}-postgres-1" psql -U postgres -d codelist
    ;;
  registries)
    check_container "${project_name}-postgres-1"
    docker exec -it "${project_name}-postgres-1" psql -U postgres -d registries
    ;;
  *)
    echo "Error: Unknown service '$service'" >&2
    echo "Available services: admin, studies, codelist, registries" >&2
    exit 1
    ;;
esac
