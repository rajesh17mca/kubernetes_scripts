#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

# ================================
# Configuration
# ================================
CONFIG_DIR="/var/lib/kubernetes"
ENCRYPTION_FILE="${CONFIG_DIR}/encryption-at-rest.yaml"
AUDIT_LOGGING_FILE="${CONFIG_DIR}/logging.yaml"

# ================================
# Logging Function
# ================================
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ================================
# Create Directory
# ================================
log "Creating config directory: ${CONFIG_DIR}"
mkdir -p "$CONFIG_DIR"
cd "$CONFIG_DIR"

# ================================
# Generate Encryption Key
# ================================
log "Generating encryption key..."
ENCRYPTION_KEY=$(openssl rand -base64 32)
log "Encryption key generated."

# ================================
# Write Encryption Config
# ================================
log "Writing encryption-at-rest.yaml..."
cat > "$ENCRYPTION_FILE" <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

log "Encryption config written to ${ENCRYPTION_FILE}"

# ================================
# Write Audit Logging Policy
# ================================
log "Writing audit logging policy to logging.yaml..."
cat > "$AUDIT_LOGGING_FILE" <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
EOF

log "Audit logging policy written to ${AUDIT_LOGGING_FILE}"

log "✅ All configurations generated successfully."
