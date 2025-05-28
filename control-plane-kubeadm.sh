#!/bin/bash

set -euo pipefail

log() {
  echo -e "\e[32m[INFO] $1\e[0m"
}

error_exit() {
  echo -e "\e[31m[ERROR] $1\e[0m"
  exit 1
}

# 1. Load kernel modules
log "Configuring kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay || error_exit "Failed to load module: overlay"
modprobe br_netfilter || error_exit "Failed to load module: br_netfilter"

# 2. Sysctl params required by Kubernetes
log "Setting sysctl params for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system || error_exit "sysctl reload failed"

# 3. Install containerd
log "Installing containerd..."
sudo apt-get update && sudo apt-get install -y containerd || error_exit "Failed to install containerd"

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# 4. Enable SystemdCgroup
log "Setting SystemdCgroup = true in containerd config..."
sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/,/^\[/ s/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || error_exit "Failed to update SystemdCgroup"

systemctl restart containerd || error_exit "Failed to restart containerd"

# 5. Additional sysctl for k8s
log "Applying additional sysctl config..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system || error_exit "sysctl reload failed"

# 6. Install kubeadm, kubelet, kubectl
log "Installing kubeadm, kubelet, kubectl..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg || error_exit "Failed to install pre-reqs"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || error_exit "Failed to add Kubernetes GPG key"

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt-get update
sudo apt-get install -y kubelet=1.32.0-1.1 kubeadm=1.32.0-1.1 kubectl=1.32.0-1.1 cri-tools=1.32.0-1.1 || error_exit "Failed to install Kubernetes packages"
sudo apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet || error_exit "Failed to enable kubelet"

# 7. Initialize Kubernetes cluster
log "Initializing Kubernetes cluster with kubeadm..."
kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.32.0 || error_exit "kubeadm init failed"

# 8. Configure kubectl
log "Setting up kubectl config..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config || error_exit "Failed to copy admin.conf"
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 9. Untaint control-plane node
#kubectl taint nodes --all node-role.kubernetes.io/control-plane- || log "No taint to remove or already done"

# 10. Install Calico CNI
log "Deploying Calico CNI..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml || error_exit "Failed to deploy tigera-operator"
sleep 10
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml || error_exit "Failed to deploy custom Calico resources"

log "Kubernetes setup completed successfully."
