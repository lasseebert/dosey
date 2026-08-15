#!/usr/bin/env bash
set -euo pipefail

APP_NAME="dosey"
DEPLOY_HOST="${1:-${DEPLOY_HOST:-dosey.dk}}"
DEPLOY_USER="${DEPLOY_USER:-root}"
REMOTE_EDITOR="${REMOTE_EDITOR:-nano}"
REMOTE_TERM="${REMOTE_TERM:-xterm-256color}"
REMOTE_ENV_FILE="/etc/${APP_NAME}/${APP_NAME}.env"
REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"

if [[ "${DEPLOY_USER}" == "root" ]]; then
  ssh -t "${REMOTE}" "TERM='${REMOTE_TERM}' ${REMOTE_EDITOR} '${REMOTE_ENV_FILE}'"
else
  ssh -t "${REMOTE}" "TERM='${REMOTE_TERM}' sudo ${REMOTE_EDITOR} '${REMOTE_ENV_FILE}'"
fi
