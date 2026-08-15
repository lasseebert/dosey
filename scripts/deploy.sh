#!/usr/bin/env bash
set -euo pipefail

APP_NAME="dosey"
DOMAIN_NAME="dosey.dk"
DEPLOY_HOST="${1:-${DEPLOY_HOST:-dosey.dk}}"
DEPLOY_USER="${DEPLOY_USER:-root}"
REMOTE_RELEASES_DIR="/opt/${APP_NAME}/releases"
REMOTE_SERVER_FILES_DIR="/opt/${APP_NAME}/server_files"
REMOTE_CURRENT_DIR="/opt/${APP_NAME}/current"
LOCAL_TMP_DIR="${TMPDIR:-/tmp}"
RELEASE_TAR="${LOCAL_TMP_DIR}/${APP_NAME}-release.tar.gz"
SERVER_FILES_TAR="${LOCAL_TMP_DIR}/${APP_NAME}-server-files.tar.gz"
RELEASE_ID="$(date -u +%Y%m%d%H%M%S)"

REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"

echo "Building ${APP_NAME} release"
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite

echo "Packaging release and server files"
tar -C "_build/prod/rel" -czf "${RELEASE_TAR}" "${APP_NAME}"
tar -C "server_files" -czf "${SERVER_FILES_TAR}" .

echo "Uploading packages to ${REMOTE}"
scp "${RELEASE_TAR}" "${SERVER_FILES_TAR}" "${REMOTE}:/tmp/"

echo "Installing release on ${REMOTE}"
ssh "${REMOTE}" \
  "APP_NAME='${APP_NAME}' \
  DOMAIN_NAME='${DOMAIN_NAME}' \
  RELEASE_ID='${RELEASE_ID}' \
  REMOTE_RELEASES_DIR='${REMOTE_RELEASES_DIR}' \
  REMOTE_SERVER_FILES_DIR='${REMOTE_SERVER_FILES_DIR}' \
  REMOTE_CURRENT_DIR='${REMOTE_CURRENT_DIR}' \
  bash -s" <<'EOF'
set -euo pipefail

RELEASE_DIR="${REMOTE_RELEASES_DIR}/${RELEASE_ID}"
PREVIOUS_RELEASE="$(readlink -f "${REMOTE_CURRENT_DIR}" 2>/dev/null || true)"
NGINX_AVAILABLE="/etc/nginx/sites-available/${APP_NAME}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${APP_NAME}"
CERT_PATH="/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem"
ENV_FILE="/etc/${APP_NAME}/${APP_NAME}.env"

if ! id -u "${APP_NAME}" >/dev/null 2>&1; then
  useradd --system --home "/opt/${APP_NAME}" --shell /usr/sbin/nologin "${APP_NAME}"
fi

if ! command -v nginx >/dev/null 2>&1 || ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nginx certbot
fi

install -d -o "${APP_NAME}" -g "${APP_NAME}" "${REMOTE_RELEASES_DIR}" "${RELEASE_DIR}" "${REMOTE_SERVER_FILES_DIR}"
install -d -m 0750 -o root -g "${APP_NAME}" "/etc/${APP_NAME}"
install -d -m 0755 /var/www/certbot

rm -rf "${REMOTE_SERVER_FILES_DIR:?}/"*
tar -xzf "/tmp/${APP_NAME}-server-files.tar.gz" -C "${REMOTE_SERVER_FILES_DIR}"

tar -xzf "/tmp/${APP_NAME}-release.tar.gz" -C "${RELEASE_DIR}" --strip-components=1
chown -R "${APP_NAME}:${APP_NAME}" "${RELEASE_DIR}" "${REMOTE_SERVER_FILES_DIR}"

install -m 0644 "${REMOTE_SERVER_FILES_DIR}/systemd/${APP_NAME}.service" "/etc/systemd/system/${APP_NAME}.service"

if [[ -f "${REMOTE_SERVER_FILES_DIR}/postgres-ca.crt" ]]; then
  install -m 0644 -o root -g root "${REMOTE_SERVER_FILES_DIR}/postgres-ca.crt" "/etc/${APP_NAME}/postgres-ca.crt"
fi

if [[ -f "${CERT_PATH}" ]]; then
  install -m 0644 "${REMOTE_SERVER_FILES_DIR}/nginx/${APP_NAME}.https.conf" "${NGINX_AVAILABLE}"
else
  install -m 0644 "${REMOTE_SERVER_FILES_DIR}/nginx/${APP_NAME}.http.conf" "${NGINX_AVAILABLE}"
  echo "TLS certificate not found at ${CERT_PATH}; installed HTTP bootstrap Nginx config."
  echo "After DNS points at this droplet, issue the certificate with:"
  echo "certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME}"
  echo "Then run this deploy again to enable HTTPS."
fi

ln -sfn "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl reload nginx || systemctl restart nginx

if [[ ! -f "${ENV_FILE}" ]]; then
  install -m 0640 -o root -g "${APP_NAME}" "${REMOTE_SERVER_FILES_DIR}/${APP_NAME}.env.example" "${ENV_FILE}"
  echo "Created /etc/${APP_NAME}/${APP_NAME}.env. Fill in real values, then run this deploy again."
  systemctl daemon-reload
  systemctl enable "${APP_NAME}"
  exit 0
fi

if grep -Eq '^(PHX_HOST=example\.com|DATABASE_URL=replace-with-managed-postgres-connection-string|SECRET_KEY_BASE=replace-with-output-from-mix-phx-gen-secret)$' "${ENV_FILE}"; then
  echo "/etc/${APP_NAME}/${APP_NAME}.env still contains placeholder values. Fill them in, then run this deploy again."
  exit 1
fi

systemctl daemon-reload
systemctl enable "${APP_NAME}"
systemctl stop "${APP_NAME}" || true

restore_previous_release() {
  if [[ -n "${PREVIOUS_RELEASE}" && -d "${PREVIOUS_RELEASE}" ]]; then
    ln -sfn "${PREVIOUS_RELEASE}" "${REMOTE_CURRENT_DIR}"
    chown -h "${APP_NAME}:${APP_NAME}" "${REMOTE_CURRENT_DIR}"
    systemctl start "${APP_NAME}" || true
  fi
}

run_release_with_env() {
  local env_args=()
  local line

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*$ || "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      env_args+=("${line}")
    else
      echo "Unsupported environment file line: ${line}"
      return 1
    fi
  done < "${ENV_FILE}"

  env "${env_args[@]}" "$@"
}

trap restore_previous_release ERR

ln -sfn "${RELEASE_DIR}" "${REMOTE_CURRENT_DIR}"
chown -h "${APP_NAME}:${APP_NAME}" "${REMOTE_CURRENT_DIR}"
run_release_with_env "${REMOTE_CURRENT_DIR}/bin/${APP_NAME}" eval "Dosey.Release.migrate()"

trap - ERR
systemctl restart "${APP_NAME}"
systemctl --no-pager --full status "${APP_NAME}"
EOF

echo "Deploy complete"
