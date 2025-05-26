#!/bin/bash

# ------------------ CONFIGURATION ------------------
CERT_DIR="/root/certificates"
CERT_FILE="$CERT_DIR/etcd.crt"
KEY_FILE="$CERT_DIR/etcd.key"
CA_FILE="$CERT_DIR/ca.crt"
CLIENT_URL="https://127.0.0.1:2379"
# ---------------------------------------------------

# Function to print and log errors
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check etcd binary
if ! command -v etcd &> /dev/null; then
    error_exit "etcd is not installed or not in PATH."
fi

# Validate directory
if [ ! -d "$CERT_DIR" ]; then
    error_exit "Certificate directory '$CERT_DIR' does not exist."
fi

# Validate certificate files
[ -f "$CERT_FILE" ] || error_exit "Certificate file '$CERT_FILE' not found."
[ -f "$KEY_FILE" ]  || error_exit "Key file '$KEY_FILE' not found."
[ -f "$CA_FILE" ]   || error_exit "CA file '$CA_FILE' not found."

echo "[INFO] Starting etcd with TLS and client authentication..."
etcd \
  --cert-file="$CERT_FILE" \
  --key-file="$KEY_FILE" \
  --advertise-client-urls="$CLIENT_URL" \
  --listen-client-urls="$CLIENT_URL" \
  --client-cert-auth \
  --trusted-ca-file="$CA_FILE"

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    error_exit "etcd exited with error code $EXIT_CODE"
fi

echo "[SUCCESS] etcd started successfully with TLS."
