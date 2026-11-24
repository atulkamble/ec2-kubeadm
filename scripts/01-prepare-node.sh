#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
[[ ! -f /etc/kubernetes/kubelet.conf && ! -f /etc/kubernetes/admin.conf ]] || { echo 'Existing cluster node; stop'; exit 1; }
case "${1:-}" in server|worker1|worker2) hostnamectl set-hostname "$1";; *) echo "Usage: sudo bash $0 server|worker1|worker2"; exit 1;; esac
dnf upgrade -y
# Use the current AL2023 AMI; older releases may require an explicit release upgrade.
# See docs/runtime.md before proceeding if containerd is incompatible.
dnf install -y conntrack-tools socat iproute-tc git tar iptables curl
getenforce
uname -r
swapoff -a
sed -i.bak '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
[[ -z $(swapon --noheadings --show) ]] || { echo 'Swap remains enabled'; exit 1; }
[[ $(sysctl -n net.ipv4.ip_forward) == 1 ]]
echo "Preparation complete. Reboot if kernel updates require it."
