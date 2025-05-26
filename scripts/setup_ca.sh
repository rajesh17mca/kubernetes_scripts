#!/bin/bash

# Enable strict mode: exit on error, undefined vars, and failed pipes
set -euo pipefail
IFS=$'\n\t'

# Variables
CERT_DIR="/root/certificates"
CA_KEY="${CERT_DIR}/ca.key"
CA_CSR="${CERT_DIR}/ca.csr"
CA_CRT="${CERT_DIR}/ca.crt"
CN="HETHVIK-KUBERNETES-CA"
DAYS_VALID=1000

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure certificate directory exists
log "Ensuring certificate directory exists: ${CERT_DIR}"
mkdir -p "${CERT_DIR}"

cd "${CERT_DIR}"

# Generate private key if not exists
if [[ -f "${CA_KEY}" ]]; then
    log "Warning: Private key ${CA_KEY} already exists. Skipping generation."
else
    log "Generating private key..."
    openssl genrsa -out "${CA_KEY}" 2048
    log "Private key created at ${CA_KEY}"
fi

# Generate CSR if not exists
if [[ -f "${CA_CSR}" ]]; then
    log "Warning: CSR ${CA_CSR} already exists. Skipping generation."
else
    log "Generating CSR with CN=${CN}..."
    openssl req -new -key "${CA_KEY}" -subj "/CN=${CN}" -out "${CA_CSR}"
    log "CSR created at ${CA_CSR}"
fi

# Generate self-signed certificate if not exists
if [[ -f "${CA_CRT}" ]]; then
    log "Warning: Certificate ${CA_CRT} already exists. Skipping creation."
else
    log "Creating self-signed certificate valid for ${DAYS_VALID} days..."
    openssl x509 -req -in "${CA_CSR}" -signkey "${CA_KEY}" -out "${CA_CRT}" -days "${DAYS_VALID}"
    log "Certificate created at ${CA_CRT}"
fi

log "Certificate Authority configuration process completed successfully."
