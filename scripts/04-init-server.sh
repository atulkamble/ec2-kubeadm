#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as ec2-user, not root"; exit 1; }
[[ $(hostname -s) == server ]] || { echo "Server only"; exit 1; }
ip=${1:?Usage: bash scripts/04-init-server.sh SERVER_PRIVATE_IP}
ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$ip" || { echo "IP is not assigned locally"; exit 1; }
sudo test ! -f /etc/kubernetes/admin.conf || { echo "Already initialized; stop"; exit 1; }
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock info >/dev/null
sudo kubeadm init --apiserver-advertise-address="$ip" --kubernetes-version="$(kubeadm version -o short)" --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock
mkdir -p "$HOME/.kube"
sudo install -o "$(id -u)" -g "$(id -g)" -m 600 /etc/kubernetes/admin.conf "$HOME/.kube/config"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sudo kubeadm token create --print-join-command
