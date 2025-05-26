#!/bin/bash

# ------------------ CONFIGURATION ------------------
CERT_DIR="/root/certificates"
CLIENT_KEY="client.key"
CLIENT_CSR="client.csr"
CLIENT_CRT="client.crt"
CA_CRT="ca.crt"
CA_KEY="ca.key"
SERIAL_FILE="ca.srl"
DAYS_VALID=1000
COMMON_NAME="client"
# ---------------------------------------------------

# Function to print errors and exit
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Ensure certificate directory exists
if [ ! -d "$CERT_DIR" ]; then
    error_exit "Certificate directory '$CERT_DIR' does not exist."
fi

cd "$CERT_DIR" || error_exit "Failed to change to directory $CERT_DIR."

echo "[INFO] Using certificate directory: $CERT_DIR"

# Check if CA certificate and key exist
[ -f "$CA_CRT" ] || error_exit "CA certificate '$CA_CRT' not found."
[ -f "$CA_KEY" ] || error_exit "CA key '$CA_KEY' not found."

# Step 1: Generate client private key
echo "[INFO] Generating client private key..."
if ! openssl genrsa -out "$CLIENT_KEY" 2048; then
    error_exit "Failed to generate client private key."
fi

# Step 2: Generate Certificate Signing Request (CSR)
echo "[INFO] Generating client CSR..."
if ! openssl req -new -key "$CLIENT_KEY" -subj "/CN=$COMMON_NAME" -out "$CLIENT_CSR"; then
    error_exit "Failed to generate client CSR."
fi

# Step 3: Sign the CSR with the CA
echo "[INFO] Signing the client CSR with CA..."
if ! openssl x509 -req \
        -in "$CLIENT_CSR" \
        -CA "$CA_CRT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$CLIENT_CRT" \
        -days "$DAYS_VALID"; then
    error_exit "Failed to sign client CSR."
fi

# Step 4: Display certificate details
echo "[INFO] Client certificate generated. Displaying certificate info:"
if ! openssl x509 -in "$CLIENT_CRT" -text -noout; then
    error_exit "Failed to display client certificate details."
fi

# Step 5: Verify certificate against the CA
echo "[INFO] Verifying client certificate against CA..."
if openssl verify -CAfile "$CA_CRT" "$CLIENT_CRT"; then
    echo "[SUCCESS] Client certificate verification passed."
else
    error_exit "Client certificate verification failed."
fi

echo "[DONE] Client certificate generation complete."
