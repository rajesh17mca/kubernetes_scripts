#!/bin/bash

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# ===============================
# Configuration
# ===============================
CERT_DIR="/root/certificates"
USER_NAME="hethvik"
CN="${USER_NAME}"
ORG="system:masters"
KEY_FILE="${CERT_DIR}/${USER_NAME}.key"
CSR_FILE="${CERT_DIR}/${USER_NAME}.csr"
CRT_FILE="${CERT_DIR}/${USER_NAME}.crt"
CA_KEY="${CERT_DIR}/ca.key"
CA_CRT="${CERT_DIR}/ca.crt"
SERIAL_FILE="${CERT_DIR}/ca.srl"
DAYS_VALID=1000

# ===============================
# Logging function
# ===============================
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# ===============================
# Validation
# ===============================
if [[ ! -d "${CERT_DIR}" ]]; then
    log "Error: Certificate directory ${CERT_DIR} does not exist."
    exit 1
fi

cd "${CERT_DIR}"

for file in "${CA_KEY}" "${CA_CRT}"; do
    if [[ ! -f "${file}" ]]; then
        log "Error: Required file ${file} not found."
        exit 1
    fi
done

# ===============================
# Key Generation
# ===============================
if [[ -f "${KEY_FILE}" ]]; then
    log "Private key already exists: ${KEY_FILE}, skipping generation."
else
    log "Generating private key for ${USER_NAME}..."
    openssl genrsa -out "${KEY_FILE}" 2048
fi

# ===============================
# CSR Generation
# ===============================
if [[ -f "${CSR_FILE}" ]]; then
    log "CSR already exists: ${CSR_FILE}, skipping generation."
else
    log "Generating CSR for ${USER_NAME}..."
    openssl req -new -key "${KEY_FILE}" -subj "/CN=${CN}/O=${ORG}" -out "${CSR_FILE}"
fi

# ===============================
# Certificate Signing
# ===============================
if [[ -f "${CRT_FILE}" ]]; then
    log "Certificate already exists: ${CRT_FILE}, skipping signing."
else
    log "Signing certificate with Kubernetes CA..."
    openssl x509 -req \
        -in "${CSR_FILE}" \
        -CA "${CA_CRT}" \
        -CAkey "${CA_KEY}" \
        -CAcreateserial \
        -CAserial "${SERIAL_FILE}" \
        -out "${CRT_FILE}" \
        -days "${DAYS_VALID}"

    log "Certificate created: ${CRT_FILE}"
fi

log "User certificate for '${USER_NAME}' successfully generated."
