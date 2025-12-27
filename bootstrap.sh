#!/bin/bash
set -euo pipefail

print_usage() {
    cat <<EOF
Usage: $0 [options] [tags]

Before running this script, you must export the required environment variables:
  export ROOT_PASSWORD='your_root_password'
  export GIT_TOKEN='your_github_token'

Options:
  --check          Run Ansible playbook in dry-run mode (no changes applied)
  --usage, --help  Show this usage message

Tags:
  Any positional arguments are treated as Ansible tags to run specific tasks.
  Available main tags:-
    base                - System update, packages and services
    security            - Security hardening (SSH, firewall, fail2ban)
    users               - User accounts and SSH keys
    cert_management     - Manage Cert - Apply and Backup
    panel               - Web UI cockpit installation
    k3s                 - K3s and headlamp dashboard installation
  Optional tags:- 
    cert_backup         - Backup apps certificates

Examples:
  $0                   Run full playbook
  $0 --check           Dry-run full playbook
  $0 k3s security      Run only tasks with tags 'k3s' and 'security'
  $0 --check k3s       Dry-run tasks with tag 'k3s'
EOF
    exit 0
}

install_if_missing() {
    for pkg in "$@"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            sudo dnf install -y "$pkg"
        fi
    done
}

# -------------------------------
# Parse options
# -------------------------------
DRY_RUN=false
POSITIONAL=()

for arg in "$@"; do
    case "$arg" in
        --check)
            DRY_RUN=true
            ;;
        --help|--usage)
            print_usage
            ;;
        *)
            POSITIONAL+=("$arg")
            ;;
    esac
done

# Tags are remaining positional arguments
TAGS="${POSITIONAL[*]}"

# -------------------------------
# Check required environment variables
# -------------------------------
if [ -z "${ROOT_PASSWORD:-}" ]; then
    echo "ERROR: ROOT_PASSWORD is not set. Exiting."
    exit 1
fi

if [ -z "${GIT_TOKEN:-}" ]; then
    echo "ERROR: GIT_TOKEN is not set. Exiting."
    exit 1
fi

export ROOT_PASSWORD
export GIT_TOKEN

GIT_USERNAME="aimanwhb"
MAIN_REPO="https://github.com/$GIT_USERNAME/myvpsbootstrap.git"
MAIN_DIR="myvpsbootstrap"
SECRET_REPO="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_USERNAME}/secrets.git"
SECRET_DIR="secrets"


install_if_missing git epel-release ansible

# -------------------------------
# Clone or update main repo
# -------------------------------
if [ ! -d "$MAIN_DIR" ]; then
    echo "[+] Cloning repo..."
    git clone "$MAIN_REPO"
else
    echo "[+] Repo exists, pulling latest..."
    cd "$MAIN_DIR"
    git pull
    cd ..
fi

# -------------------------------
# Clone or update secrets repo
# -------------------------------
if [ ! -d "$SECRET_DIR" ]; then
    echo "[+] Cloning repo..."
    git clone "$SECRET_REPO"
else
    echo "[+] Repo exists, pulling latest..."
    cd "$SECRET_DIR"
    git pull
    cd ..
fi

# ------------------------------------------
# Update vars.yaml file from secrets repo
# ------------------------------------------
cp -f "$SECRET_DIR"/vars.yaml  "$MAIN_DIR"/ansible/playbooks/var/vars.yaml
if [ "$?" -eq 0 ]; then 
    echo "Successfully updated vars.yaml"
else
    echo "Error updating vars.yaml"
    exit 1
fi

# -------------------------------
# Tags info
# -------------------------------
if [ -n "$TAGS" ]; then
    echo "[+] Running with tags: $TAGS"
else
    echo "[+] Running full playbook (no tags)."
fi

if [ "$DRY_RUN" = true ]; then
    echo "[+] Dry-run enabled (--check)"
fi

# -------------------------------
# Run Ansible playbook
# -------------------------------
ANSIBLE_CMD=(ansible-playbook -i "$MAIN_DIR/ansible/inventory/hosts" "$MAIN_DIR/ansible/playbooks/main.yaml")

if [ -n "$TAGS" ]; then
    TAGS_CSV=$(echo "$TAGS" | tr ' ' ',')
    ANSIBLE_CMD+=(--tags "$TAGS_CSV")
fi

if [ "$DRY_RUN" = true ]; then
    ANSIBLE_CMD+=(--check)
fi

# Execute
"${ANSIBLE_CMD[@]}"