#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

SERVICE_NAME="etcd"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload

# Restart kube-apiserver
log "Restarting ${SERVICE_NAME} service..."
if systemctl restart "${SERVICE_NAME}"; then
    log "Service ${SERVICE_NAME} restarted successfully."
else
    log "❌ Failed to restart ${SERVICE_NAME}."
    exit 1
fi

# Check status
log "Fetching ${SERVICE_NAME} status..."
systemctl status "${SERVICE_NAME}" --no-pager
