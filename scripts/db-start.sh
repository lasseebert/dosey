#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="dosey-postgres"
VOLUME_NAME="dosey-postgres-data"
POSTGRES_VERSION="${POSTGRES_VERSION:-18}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
START_TIMEOUT_SECONDS="${START_TIMEOUT_SECONDS:-30}"
IMAGE="docker.io/library/postgres:${POSTGRES_VERSION}"

create_container() {
  podman volume exists "${VOLUME_NAME}" || podman volume create "${VOLUME_NAME}" >/dev/null

  podman run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --publish "127.0.0.1:${POSTGRES_PORT}:5432" \
    --env "POSTGRES_USER=${POSTGRES_USER}" \
    --env "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    --volume "${VOLUME_NAME}:/var/lib/postgresql:Z" \
    "${IMAGE}" >/dev/null
}

if podman container exists "${CONTAINER_NAME}"; then
  if podman inspect --format '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' "${CONTAINER_NAME}" | grep -qx '/var/lib/postgresql/data'; then
    echo "Recreating ${CONTAINER_NAME} with the PostgreSQL 18 volume mount layout."
    podman rm "${CONTAINER_NAME}" >/dev/null
    create_container
  else
    podman start "${CONTAINER_NAME}" >/dev/null
  fi
else
  create_container
fi

echo "Waiting for PostgreSQL on 127.0.0.1:${POSTGRES_PORT}"

started_at="$(date +%s)"

until podman exec "${CONTAINER_NAME}" pg_isready -h 127.0.0.1 -p 5432 -U "${POSTGRES_USER}" >/dev/null 2>&1; do
  if ! podman container exists "${CONTAINER_NAME}" || [[ "$(podman inspect --format '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
    echo "PostgreSQL container is not running. Recent logs:"
    podman logs --tail 80 "${CONTAINER_NAME}" || true
    exit 1
  fi

  if (( "$(date +%s)" - started_at >= START_TIMEOUT_SECONDS )); then
    echo "Timed out waiting for PostgreSQL after ${START_TIMEOUT_SECONDS} seconds. Recent logs:"
    podman logs --tail 80 "${CONTAINER_NAME}" || true
    exit 1
  fi

  sleep 1
done

echo "PostgreSQL is ready."
