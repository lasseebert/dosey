#!/usr/bin/env bash
set -euo pipefail

APP_NAME="dosey"
DEPLOY_HOST="${1:-${DEPLOY_HOST:-dosey.dk}}"
DEPLOY_USER="${DEPLOY_USER:-root}"
REMOTE_TERM="${REMOTE_TERM:-xterm-256color}"
REMOTE_CURRENT_DIR="/opt/${APP_NAME}/current"
REMOTE_ENV_FILE="/etc/${APP_NAME}/${APP_NAME}.env"
REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"

REMOTE_SCRIPT="$(cat <<'EOF'
set -euo pipefail

if [[ ! -f "${REMOTE_ENV_FILE}" ]]; then
  echo "Missing environment file: ${REMOTE_ENV_FILE}" >&2
  exit 1
fi

if [[ ! -x "${REMOTE_CURRENT_DIR}/bin/${APP_NAME}" ]]; then
  echo "Missing release command: ${REMOTE_CURRENT_DIR}/bin/${APP_NAME}" >&2
  exit 1
fi

if ! systemctl is-active --quiet "${APP_NAME}"; then
  echo "${APP_NAME} is not running; start it before attaching a remote console." >&2
  exit 1
fi

cd "${REMOTE_CURRENT_DIR}"

exec sudo -u "${APP_NAME}" bash -c '
  set -euo pipefail

  app_name="$1"
  current_dir="$2"
  env_file="$3"
  remote_term="$4"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*$ || "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "${line}"
    else
      echo "Unsupported environment file line: ${line}" >&2
      exit 1
    fi
  done < "${env_file}"

  export TERM="${remote_term}"
  cd "${current_dir}"
  exec "${current_dir}/bin/${app_name}" remote
' bash "${APP_NAME}" "${REMOTE_CURRENT_DIR}" "${REMOTE_ENV_FILE}" "${REMOTE_TERM}"
EOF
)"

printf -v REMOTE_COMMAND \
  "APP_NAME=%q REMOTE_CURRENT_DIR=%q REMOTE_ENV_FILE=%q REMOTE_TERM=%q TERM=%q bash -lc %q" \
  "${APP_NAME}" \
  "${REMOTE_CURRENT_DIR}" \
  "${REMOTE_ENV_FILE}" \
  "${REMOTE_TERM}" \
  "${REMOTE_TERM}" \
  "${REMOTE_SCRIPT}"

ssh -tt "${REMOTE}" "${REMOTE_COMMAND}"
