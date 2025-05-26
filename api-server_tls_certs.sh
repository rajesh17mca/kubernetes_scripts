#!/bin/bash

set -euo pipefail

# Variables
CERT_DIR="/root/certificates"
CA_KEY="${CERT_DIR}/ca.key"
CA_CERT="${CERT_DIR}/ca.crt"
CA_SERIAL="${CERT_DIR}/ca.srl"

APISERVER_KEY="${CERT_DIR}/apiserver.key"
APISERVER_CSR="${CERT_DIR}/apiserver.csr"
APISERVER_CERT="${CERT_DIR}/apiserver.crt"
APISERVER_CONF="${CERT_DIR}/apiserver-openssl.cnf"

APISERVER_CN="kube-apiserver"
METADATA_URL="http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check required commands
for cmd in openssl curl; do
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "'$cmd' is not installed or not in PATH."
    fi
done

# Create certificate directory if needed
mkdir -p "${CERT_DIR}"
chmod 700 "${CERT_DIR}"

# Fetch external IP
log "Fetching public IP address from metadata service..."
IP_ADDRESS=$(curl -sf "${METADATA_URL}" || true)
if [[ -z "${IP_ADDRESS}" ]]; then
    error_exit "Could not retrieve IP address from metadata URL."
fi
log "Using IP address: ${IP_ADDRESS}"

# Generate CA if needed
if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
    log "Generating new CA key and certificate..."
    openssl genrsa -out "${CA_KEY}" 2048
    openssl req -x509 -new -nodes -key "${CA_KEY}" -subj "/CN=Kubernetes-CA" \
        -days 10000 -out "${CA_CERT}"
    log "CA certificate created at ${CA_CERT}"
else
    log "CA certificate already exists. Skipping CA generation."
fi

# Create OpenSSL config
log "Creating OpenSSL config for kube-apiserver cert..."
cat > "${APISERVER_CONF}" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = ${APISERVER_CN}

[v3_req]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 127.0.0.1
IP.2 = 10.96.0.1
IP.3 = ${IP_ADDRESS}
EOF

# Generate API server key
if [[ -f "${APISERVER_KEY}" ]]; then
    log "API server private key already exists. Skipping."
else
    log "Generating API server private key..."
    openssl genrsa -out "${APISERVER_KEY}" 2048
fi

# Generate CSR
log "Generating Certificate Signing Request (CSR)..."
openssl req -new -key "${APISERVER_KEY}" \
    -subj "/CN=${APISERVER_CN}" \
    -out "${APISERVER_CSR}" \
    -config "${APISERVER_CONF}"

# Sign the certificate
log "Signing the API server certificate with CA..."
openssl x509 -req \
    -in "${APISERVER_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -CAserial "${CA_SERIAL}" \
    -out "${APISERVER_CERT}" \
    -days 3650 \
    -extensions v3_req \
    -extfile "${APISERVER_CONF}"

# Verify certificate creation
if [[ -f "${APISERVER_CERT}" ]]; then
    log "✅ API server certificate generated at ${APISERVER_CERT}"
else
    error_exit "API server certificate generation failed."
fi
