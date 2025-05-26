#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and prevent errors in a pipeline from being masked
set -euo pipefail

# Configuration
ETCD_VER="v3.6.0"
GITHUB_URL="https://github.com/etcd-io/etcd/releases/download"
DOWNLOAD_URL="${GITHUB_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"
INSTALL_DIR="/root/binaries"
EXTRACT_DIR="${INSTALL_DIR}/etcd"
ARCHIVE="${INSTALL_DIR}/etcd-${ETCD_VER}-linux-amd64.tar.gz"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure required directories exist
log "Creating directory ${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"

cd "${INSTALL_DIR}"

# Download ETCD tarball
log "Downloading etcd ${ETCD_VER} binaries from ${DOWNLOAD_URL}"
if curl -fL "${DOWNLOAD_URL}" -o "${ARCHIVE}"; then
    log "Download complete"
else
    log "Failed to download etcd archive. Check the version or URL."
    exit 1
fi

# Extract the archive
log "Extracting etcd archive"
if tar xzvf "${ARCHIVE}" -C "${EXTRACT_DIR}" --strip-components=1 --no-same-owner; then
    log "Extraction successful"
    rm -f "${ARCHIVE}"
else
    log "Extraction failed"
    exit 1
fi

# Verify binaries
log "Verifying installed etcd binaries"
if [[ -x "${EXTRACT_DIR}/etcd" && -x "${EXTRACT_DIR}/etcdctl" ]]; then
    "${EXTRACT_DIR}/etcd" --version
    "${EXTRACT_DIR}/etcdctl" version
    if [[ -x "${EXTRACT_DIR}/etcdutl" ]]; then
        "${EXTRACT_DIR}/etcdutl" version
    else
        log "Warning: etcdutl binary not found"
    fi
else
    log "Error: etcd or etcdctl binary not found or not executable"
    exit 1
fi

# Move binaries to /usr/local/bin
log "Copying etcd and etcdctl to /usr/local/bin"
cp "${EXTRACT_DIR}/etcd" "${EXTRACT_DIR}/etcdctl" /usr/local/bin/

log "Installation complete. You can now use etcd and etcdctl from anywhere."

# Create data directory with secure permissions
sudo mkdir -p /var/lib/etcd
sudo chmod 700 /var/lib/etcd
# Optional: change ownership if etcd runs under a dedicated user (e.g., etcd)
# sudo chown etcd:etcd /var/lib/etcd

# Create systemd service file for etcd with TLS config
sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --cert-file=/root/certificates/etcd.crt \\
  --key-file=/root/certificates/etcd.key \\
  --trusted-ca-file=/root/certificates/ca.crt \\
  --client-cert-auth \\
  --listen-client-urls=https://127.0.0.1:2379 \\
  --advertise-client-urls=https://127.0.0.1:2379 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable etcd to start at boot
sudo systemctl enable etcd

# Start etcd service now
sudo systemctl start etcd

# Check status
sudo systemctl status etcd
