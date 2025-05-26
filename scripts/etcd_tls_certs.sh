#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

# ----------------- CONFIGURATION -----------------
CERT_DIR="/root/certificates"
CN="etcd"
ETCD_KEY="${CERT_DIR}/etcd.key"
ETCD_CSR="${CERT_DIR}/etcd.csr"
ETCD_CRT="${CERT_DIR}/etcd.crt"
ETCD_CNF="${CERT_DIR}/etcd.cnf"
CA_CERT="${CERT_DIR}/ca.crt"
CA_KEY="${CERT_DIR}/ca.key"
CA_SERIAL="${CERT_DIR}/ca.srl"
DAYS_VALID=2000
METADATA_URL="http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address"
# -------------------------------------------------

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Check required tools
for cmd in openssl curl; do
    if ! command -v "$cmd" &> /dev/null; then
        log "Error: '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Fetch public IP address
log "Fetching public IP address from metadata..."
IP_ADDRESS=$(curl -sf "$METADATA_URL" || true)
if [[ -z "${IP_ADDRESS}" ]]; then
    log "Error: Could not retrieve IP address from metadata URL."
    exit 1
fi
log "Retrieved IP address: ${IP_ADDRESS}"

# Ensure certificate directory exists
mkdir -p "${CERT_DIR}"
cd "${CERT_DIR}"

# Check for CA files
if [[ ! -f "${CA_CERT}" || ! -f "${CA_KEY}" ]]; then
    log "Error: CA certificate or key not found in ${CERT_DIR}"
    exit 1
fi

# Generate private key
if [[ -f "${ETCD_KEY}" ]]; then
    log "Warning: ${ETCD_KEY} already exists. Skipping key generation."
else
    log "Generating etcd private key..."
    openssl genrsa -out "${ETCD_KEY}" 2048
fi

# Create OpenSSL configuration file for SAN
log "Creating OpenSSL config file at ${ETCD_CNF}..."
cat > "${ETCD_CNF}" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
IP.1 = ${IP_ADDRESS}
IP.2 = 127.0.0.1
EOF

# Generate Certificate Signing Request (CSR)
log "Generating CSR for CN=${CN}..."
openssl req -new -key "${ETCD_KEY}" -subj "/CN=${CN}" -out "${ETCD_CSR}" -config "${ETCD_CNF}"

# Sign certificate with the CA
log "Signing etcd certificate with CA..."
openssl x509 -req \
    -in "${ETCD_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${ETCD_CRT}" \
    -extensions v3_req \
    -extfile "${ETCD_CNF}" \
    -days "${DAYS_VALID}"

# Validate the generated certificate
if [[ -f "${ETCD_CRT}" ]]; then
    log "etcd certificate created at ${ETCD_CRT}"
    log "Certificate info:"
    openssl x509 -in "${ETCD_CRT}" -noout -text
else
    log "Error: etcd certificate was not created."
    exit 1
fi

# Optional: Clean up temporary files (uncomment if desired)
# rm -f "${ETCD_CNF}" "${ETCD_CSR}"

log "All done."
