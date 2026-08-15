#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="dosey-postgres"

if podman container exists "${CONTAINER_NAME}"; then
  podman stop "${CONTAINER_NAME}"
else
  echo "Container ${CONTAINER_NAME} does not exist."
fi
