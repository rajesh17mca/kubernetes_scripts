#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

# ================================
# Variables
# ================================
BIN_DIR="/root/binaries"
CERT_DIR="/root/certificates"
K8S_VERSION="v1.32.1"
K8S_TARBALL="kubernetes-server-linux-amd64.tar.gz"
K8S_URL="https://dl.k8s.io/${K8S_VERSION}/${K8S_TARBALL}"
ETCD_SERVERS="https://127.0.0.1:2379"
SERVICE_CLUSTER_CIDR="10.0.0.0/24"
SYSTEMD_FILE="/etc/systemd/system/kube-apiserver.service"

CERT_API_KEY="${CERT_DIR}/api-etcd.key"
CERT_API_CSR="${CERT_DIR}/api-etcd.csr"
CERT_API_CRT="${CERT_DIR}/api-etcd.crt"
CERT_SA_KEY="${CERT_DIR}/service-account.key"
CERT_SA_CSR="${CERT_DIR}/service-account.csr"
CERT_SA_CRT="${CERT_DIR}/service-account.crt"
CERT_KUBEAPI_KEY="${CERT_DIR}/apiserver.key"
CERT_KUBEAPI_CRT="${CERT_DIR}/apiserver.crt"
CA_KEY="${CERT_DIR}/ca.key"
CA_CRT="${CERT_DIR}/ca.crt"

METADATA_URL="http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address"

# ================================
# Functions
# ================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

require_cmds() {
    for cmd in wget tar openssl curl systemctl; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required command '$cmd' not found. Please install it."
            exit 1
        fi
    done
}

# ================================
# Begin Script
# ================================

log "Checking required commands..."
require_cmds

log "Creating necessary directories..."
mkdir -p "$BIN_DIR" "$CERT_DIR"

# Step 1: Download and extract Kubernetes binaries
cd "$BIN_DIR"
if [[ ! -f "${K8S_TARBALL}" ]]; then
    log "Downloading Kubernetes binaries..."
    wget -q "$K8S_URL"
fi

if [[ ! -d "kubernetes" ]]; then
    log "Extracting Kubernetes binaries..."
    tar -xzf "${K8S_TARBALL}"
fi

log "Copying kube-apiserver and kubectl to /usr/local/bin..."
cp -u kubernetes/server/bin/kube-apiserver kubernetes/server/bin/kubectl /usr/local/bin/
chmod +x /usr/local/bin/kube-apiserver /usr/local/bin/kubectl

# Step 2: Verify CA certs exist
cd "$CERT_DIR"
if [[ ! -f "$CA_KEY" || ! -f "$CA_CRT" ]]; then
    log "Error: CA key or certificate not found in $CERT_DIR"
    exit 1
fi

# Step 3: Generate certificates to authenticate etcd
if [[ ! -f "$CERT_API_KEY" ]]; then
    log "Generating kube-apiserver private key to authenticate etcd..."
    openssl genrsa -out "$CERT_API_KEY" 2048
fi

if [[ ! -f "$CERT_API_CSR" ]]; then
    log "Generating kube-apiserver CSR to authenticate etcd..."
    openssl req -new -key "$CERT_API_KEY" -subj "/CN=kube-apiserver" -out "$CERT_API_CSR"
fi

if [[ ! -f "$CERT_API_CRT" ]]; then
    log "Signing kube-apiserver certificate to authenticate etcd..."
    openssl x509 -req -in "$CERT_API_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out "$CERT_API_CRT" -days 2000
fi

# Step 4: Generate service account certs
if [[ ! -f "$CERT_SA_KEY" ]]; then
    log "Generating service-account private key..."
    openssl genrsa -out "$CERT_SA_KEY" 2048
fi

if [[ ! -f "$CERT_SA_CSR" ]]; then
    log "Generating service-account CSR..."
    openssl req -new -key "$CERT_SA_KEY" -subj "/CN=service-accounts" -out "$CERT_SA_CSR"
fi

if [[ ! -f "$CERT_SA_CRT" ]]; then
    log "Signing service-account certificate..."
    openssl x509 -req -in "$CERT_SA_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out "$CERT_SA_CRT" -days 100
fi

# Step 5: Create systemd unit file
log "Creating systemd service file for kube-apiserver..."

IP_ADDRESS=$(curl -sf "$METADATA_URL" || true)
if [[ -z "${IP_ADDRESS}" ]]; then
    log "Error: Could not retrieve IP address from metadata URL."
    exit 1
fi
log "Retrieved IP address: ${IP_ADDRESS}"

cat > "$SYSTEMD_FILE" <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${IP_ADDRESS} \\
  --etcd-cafile=${CA_CRT} \\
  --etcd-certfile=${CERT_API_CRT} \\
  --etcd-keyfile=${CERT_API_KEY} \\
  --etcd-servers=${ETCD_SERVERS} \\
  --service-account-key-file=${CERT_SA_CRT} \\
  --service-account-signing-key-file=${CERT_SA_KEY} \\
  --service-account-issuer=https://127.0.0.1:6443 \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_CIDR} \\
  --tls-cert-file=${CERT_KUBEAPI_CRT} \\
  --tls-private-key-file=${CERT_KUBEAPI_KEY}

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Reload, enable and start service
log "Reloading systemd..."
systemctl daemon-reload

log "Enabling kube-apiserver service to start on boot..."
systemctl enable kube-apiserver

log "Starting kube-apiserver service..."
systemctl start kube-apiserver

log "Checking status..."
systemctl status kube-apiserver --no-pager

log "Kubernetes API Server setup completed successfully!"
