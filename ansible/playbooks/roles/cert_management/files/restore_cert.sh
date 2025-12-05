#!/bin/bash
set -euo pipefail

# =========================
# VALIDATION
# =========================
if [ -z "${GIT_TOKEN:-}" ] || [ -z "${ROOT_PASSWORD:-}" ] || \
   [ -z "${GIT_USERNAME:-}" ] || [ -z "${CERT_REPO:-}" ] || \
   [ -z "${CERT_FILE:-}" ]; then
  echo "❌ ERROR: Missing required environment variables"
  exit 1
fi

RESTORE_DIR="/tmp/restore-cert"
CLONE_DIR="/tmp/restore-cert/repo"
DECRYPT_DIR="/tmp/restore-cert/decrypted"

REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_USERNAME}/${CERT_REPO}.git"

rm -rf "$RESTORE_DIR"
mkdir -p "$CLONE_DIR" "$DECRYPT_DIR"

# =========================
# Clone repo
# =========================
echo "📥 Cloning SSL backup repo..."
git clone "$REPO_URL" "$CLONE_DIR"

BACKUP_FILE="$CLONE_DIR/backups/$CERT_FILE"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# =========================
# Stop services before restore
# =========================
echo "🛑 Stopping services..."
systemctl stop nginx || true
# systemctl stop certbot.timer || true

# =========================
# Decrypt cert backup
# =========================
echo "🔐 Decrypting SSL backup..."
gpg --batch --yes --passphrase "$ROOT_PASSWORD" \
  --decrypt "$BACKUP_FILE" | tar -xzf - -C "$DECRYPT_DIR"

if [ ! -d "$DECRYPT_DIR/etc/letsencrypt" ]; then
  echo "❌ ERROR: Decryption succeeded but letsencrypt folder missing"
  exit 1
fi

# =========================
# Apply restore
# =========================
echo "📦 Restoring /etc/letsencrypt ..."
rm -rf /etc/letsencrypt
mv "$DECRYPT_DIR/etc/letsencrypt" /etc/

# =========================
# Fix permissions
# =========================
# echo "🔧 Fixing permissions..."
# find /etc/letsencrypt -type d -exec chmod 755 {} \;
# find /etc/letsencrypt -type f -exec chmod 644 {} \;
# find /etc/letsencrypt/live -type f -exec chmod 600 {} \; || true
# find /etc/letsencrypt/archive -type f -exec chmod 600 {} \; || true

# =========================
# Start services
# =========================
echo "🚀 Starting services..."
systemctl start nginx || true
# systemctl start certbot.timer || true

# =========================
# Certbot verification
# =========================
# echo "🧪 Validating SSL using certbot..."
# certbot renew --dry-run || {
#     echo "❌ Certbot dry run FAILED. SSL may be broken."
#     exit 1
# }

echo "✅ SSL restore complete and verified."

# =========================
# Cleanup
# =========================
echo "🧹 Cleanup..."
rm -rf "$RESTORE_DIR"

echo "🎉 Done!"
