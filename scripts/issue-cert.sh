#!/usr/bin/env bash
set -euo pipefail

DOMAIN_NAME="dosey.dk"
DEPLOY_HOST="${1:-${DEPLOY_HOST:-dosey.dk}}"
DEPLOY_USER="${DEPLOY_USER:-root}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-lasse@lasseebert.dk}"
WEBROOT="/var/www/certbot"
REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"

ssh -t "${REMOTE}" \
  "DOMAIN_NAME='${DOMAIN_NAME}' CERTBOT_EMAIL='${CERTBOT_EMAIL}' WEBROOT='${WEBROOT}' bash -s" <<'EOF'
set -euo pipefail

if ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  apt-get install -y certbot
fi

install -d -m 0755 "${WEBROOT}"

certbot certonly \
  --webroot \
  -w "${WEBROOT}" \
  -d "${DOMAIN_NAME}" \
  -d "www.${DOMAIN_NAME}" \
  --email "${CERTBOT_EMAIL}" \
  --agree-tos \
  --no-eff-email
EOF

echo "Certificate issued. Run scripts/deploy.sh to enable the HTTPS Nginx config."
