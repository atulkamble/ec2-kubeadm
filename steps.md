# Quick execution checklist

Follow [README.md](README.md) for commands. This checklist is a navigation aid, not a second installation guide.

| Step | Where | Task |
|---|---|---|
| 1 | AWS Console | Create three EC2 instances, same VPC/subnet/SG and key pair |
| 2 | Workstation | Connect to each instance |
| 3 | All nodes | Assign unique hostnames |
| 4 | All nodes | Prepare OS, swap and networking |
| 5 | All nodes | Install compatible containerd |
| 6 | All nodes | Install Kubernetes components and verify versions |
| 7 | Server | Initialize control plane and configure kubectl |
| 8 | Server | Install Flannel |
| 9 | Server | Generate fresh join command |
| 10 | Both workers | Execute generated join command with sudo |
| 11 | Server | Verify three Ready nodes and system pods |
| 12 | Server | Apply YAML manifests, verify rollout, test HTTP |
| 13 | As needed | Troubleshoot |
| 14 | Server / AWS | Delete test resources and terminate lab instances |

Optional: [automated setup](docs/automation.md) replaces manual steps 3–11. Use one method only.


https://github.com/atulkamble/ec2-kubeadm

amazon linux 
SSD - 70GB 
kubeadm.pem
vpc - defeault 
SG - default 

SG - SG - Allow - Traffic 

SERVER_PUBLIC_IP=3.80.214.107
SERVER_PRIVATE_IP=172.31.29.239
WORKER1_PUBLIC_IP=100.53.137.103
WORKER1_PRIVATE_IP=172.31.30.104
WORKER2_PUBLIC_IP=3.94.193.250
WORKER2_PRIVATE_IP=172.31.29.113

sudo tee -a /etc/hosts <<'EOF'
172.31.29.239 server
172.31.30.104 worker1
172.31.29.113 worker2
EOF

SERVER_PRIVATE_IP="172.31.29.239"
sudo kubeadm init \
  --kubernetes-version="$(kubeadm version -o short)" \
  --apiserver-advertise-address="$SERVER_PRIVATE_IP" \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock


kubeadm join 172.31.29.239:6443 --token nq69s5.dbz69hr22pp2y9b2 \
	--discovery-token-ca-cert-hash sha256:d42874d49f321eb709bb58e04d30156f668aab5cb084cc7863189183fa61864e 

[ec2-user@ip-172-31-29-239 ~]$ kubectl get nodes
NAME      STATUS   ROLES           AGE    VERSION
server    Ready    control-plane   114s   v1.37.2
worker1   Ready    <none>          14s    v1.37.2
worker2   Ready    <none>          8s     v1.37.2
[ec2-user@ip-172-31-29-239 ~]$ 
