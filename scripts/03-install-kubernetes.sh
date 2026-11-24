#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
cat > /etc/yum.repos.d/kubernetes.repo <<'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.37/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.37/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
dnf install -y kubeadm kubelet kubectl cri-tools kubernetes-cni --disableexcludes=kubernetes
systemctl enable --now kubelet
cat /etc/os-release
containerd --version
kubeadm version
kubelet --version
kubectl version --client
rpm -q kubeadm kubelet kubectl
for plugin in bridge loopback host-local portmap; do
  test -x "/opt/cni/bin/$plugin" || { echo "Missing CNI plugin: $plugin"; exit 1; }
done
crictl --runtime-endpoint unix:///run/containerd/containerd.sock info >/dev/null
