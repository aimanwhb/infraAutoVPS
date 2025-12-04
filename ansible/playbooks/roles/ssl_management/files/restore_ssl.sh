#!/bin/bash
set -euo pipefail

if [ -z "${GIT_TOKEN:-}" ] || [ -z "${ROOT_PASSWORD:-}" ]; then
  echo "❌ ERROR: Missing required environment variables"
  exit 1
fi

GIT_TOKEN="$1"
ROOT_PASSWORD="$2"

GIT_USER="aimanwhb"
REPO_NAME="secrets"
DEST_DIR="/tmp/secrets"

REPO_URL="https://${GIT_USER}:${GIT_TOKEN}@github.com/${GIT_USER}/${REPO_NAME}.git"

# =========================
# CLONE REPO
# =========================
if [ ! -d "$DEST_DIR/.git" ]; then
  echo "📥 Cloning secrets repo..."
  git clone "$REPO_URL" "$DEST_DIR"
else
  echo "🔄 Updating secrets repo..."
  cd "$DEST_DIR"
  git pull
fi

# =========================
# RESTORE SSL
# =========================
echo "🔐 Restoring SSL from encrypted backup..."

gpg --batch --yes --passphrase "$ROOT_PASSWORD" \
  --decrypt "$DEST_DIR/ssl-backup.tar.gz.gpg" | tar -xzf - -C "$DEST_DIR"

if [ ! -d "$DEST_DIR/etc/letsencrypt" ]; then
  echo "❌ ERROR: Decryption succeeded but letsencrypt folder is missing"
  exit 1
fi

rm -rf /etc/letsencrypt
mv "$DEST_DIR/etc/letsencrypt" /etc/

echo "✅ SSL restore complete."
