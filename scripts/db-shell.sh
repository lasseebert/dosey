#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="dosey-postgres"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

podman exec -it "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}"
