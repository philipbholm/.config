#!/bin/bash
set -euo pipefail

export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

project_name="$(basename "$(git rev-parse --show-toplevel)")"

if [[ $# -eq 0 || -z "$1" ]]; then
  echo "Usage: db <service>"
  echo "Services: admin, studies, codelist, registries"
  exit 1
fi

service="$1"

case "$service" in
  admin)
    docker exec -it ${project_name}-mysql-1 mysql -u root -proot prjcts
    ;;
  studies)
    docker exec -it ${project_name}-postgres-1 psql -U postgres -d studies
    ;;
  codelist)
    docker exec -it ${project_name}-postgres-1 psql -U postgres -d codelist
    ;;
  registries)
    docker exec -it ${project_name}-postgres-1 psql -U postgres -d registries
    ;;
  *)
    echo "Error: Unknown service '$service'"
    echo "Available services: admin, studies, codelist, registries"
    exit 1
    ;;
esac
