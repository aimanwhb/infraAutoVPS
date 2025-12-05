#!/bin/bash
set -euo pipefail

# =========================
# VALIDATION
# =========================
if [ -z "${GIT_TOKEN:-}" ] || [ -z "${ROOT_PASSWORD:-}" ] || \
   [ -z "${GIT_USERNAME:-}" ] || [ -z "${CERT_REPO:-}" ]; then \
  echo "❌ ERROR: Missing required environment variables"
  exit 1
fi

DATE=$(date +%F)
TMP_DIR="/tmp/cert-backup-tmp"
CLONE_DIR="/tmp/cert-backup-repo"
BACKUP_FILE="ssl-backup-${DATE}.tar.gz.gpg"
REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_USERNAME}/${CERT_REPO}.git"

rm -rf "$TMP_DIR" "$CLONE_DIR"
mkdir -p "$TMP_DIR"

# =========================
# Encrypt certbot folder
# =========================
echo "🔐 Encrypting /etc/letsencrypt ..."
tar -czf - /etc/letsencrypt | \
  gpg --batch --yes --passphrase "$ROOT_PASSWORD" \
  --symmetric --cipher-algo AES256 \
  --output "$TMP_DIR/${BACKUP_FILE}"

# =========================
# Clone repo
# =========================
echo "📥 Cloning cert repo..."
git clone "$REPO_URL" "$CLONE_DIR"


mkdir -p "$CLONE_DIR/backups"

# =========================
# Move encrypted backup
# =========================
cp "$TMP_DIR/${BACKUP_FILE}" "$CLONE_DIR/backups/"

# =========================
# Commit + Push
# =========================
cd "$CLONE_DIR"
git add "backups/${BACKUP_FILE}"
git commit -m "Backup SSL cert ${DATE}"
git push origin main

echo "✅ Backup completed: backups/${BACKUP_FILE}"