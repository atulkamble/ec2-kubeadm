#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
# Fresh dedicated lab nodes only; back up existing runtime configuration.
[[ ! -f /etc/kubernetes/kubelet.conf ]] || { echo 'Node already joined; stop'; exit 1; }
if ! command -v containerd >/dev/null; then dnf install -y containerd; fi
version=$(containerd --version)
echo "$version"
if ! grep -Eq '(^|[[:space:]])v?2\.(3|4)\.[0-9]+' <<< "$version"; then
  echo "Unsupported runtime for this lab. Install containerd 2.3 or 2.4 using docs/runtime.md."
  exit 1
fi
mkdir -p /etc/containerd
if [[ -f /etc/containerd/config.toml ]]; then
  cp -n /etc/containerd/config.toml /etc/containerd/config.toml.pre-kubeadm
fi
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
grep -q 'SystemdCgroup = true' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable --now containerd
systemctl restart containerd
systemctl is-active containerd
