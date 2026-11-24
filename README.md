# Kubernetes kubeadm Cluster on AWS EC2 — Amazon Linux 2023

Hands-on lab: build a **three-node, self-managed Kubernetes cluster** with **1 control-plane server + 2 workers** using **kubeadm**, **containerd**, and **Flannel**.

> This is a disposable training lab, not a production high-availability architecture. Follow the sections in order. Commands marked **ALL NODES** run independently on all three EC2 instances; **SERVER ONLY** and **WORKERS ONLY** are role-specific.

## Technology stack

| Layer | Technology | What it does |
|---|---|---|
| Cloud | AWS EC2 | Provides three virtual machines |
| Network | VPC, subnet, security group | Connects and protects the nodes |
| Storage | EBS | Stores OS and application files |
| OS | Amazon Linux 2023 | Linux environment for Kubernetes |
| Runtime | containerd 2.3/2.4 | Runs containers |
| Orchestration | Kubernetes v1.37 | Manages containerized applications |
| Setup | kubeadm | Creates the cluster and joins workers |
| Node agent | kubelet | Keeps pods running on each node |
| CLI | kubectl | Sends commands to the Kubernetes API |
| Pod network | Flannel CNI | Connects pods across nodes |
| Test application | Nginx | Verifies application deployment |
| Automation | Bash, YAML | Automates setup and defines resources |

## Kubernetes basics

**Kubernetes (K8s)** is an open-source container orchestration platform. It deploys, scales, networks and manages containerized applications.

**Why Kubernetes?** It supports automatic recovery, scaling, service discovery, load balancing and rolling updates.

| Concept | Simple definition |
|---|---|
| Container | Isolated running application with its dependencies |
| Image | Packaged template used to create containers |
| Cluster | Group of machines managed by Kubernetes |
| Node | Physical or virtual machine in a cluster |
| Control plane | Manages cluster state and scheduling |
| Worker node | Runs application workloads |
| Pod | Smallest deployable unit; contains one or more containers |
| ReplicaSet | Maintains a desired number of matching pods |
| Deployment | Manages ReplicaSets and application updates |
| Service | Stable network endpoint for a group of pods |
| Namespace | Logical grouping of Kubernetes resources |
| DaemonSet | Runs a pod on every eligible node |
| ConfigMap | Stores non-secret configuration |
| Secret | Stores sensitive configuration; requires appropriate access and encryption controls |
| PersistentVolume | Storage resource independent of a pod |
| PersistentVolumeClaim | Request for persistent storage |
| Ingress | HTTP/HTTPS routing rules; requires an Ingress controller |
| HPA | Automatically adjusts workload replica count using metrics |
| CNI | Interface for pod networking plugins |
| CRI | Interface between kubelet and container runtime |

## Why kubeadm?

**kubeadm** is an official Kubernetes bootstrapping tool that initializes a control plane and joins nodes to a cluster. It is not a container runtime or a cloud infrastructure provisioning tool.

- Learn how a real multi-node Kubernetes cluster works.
- Understand certificates, tokens, networking and control-plane components.
- Build a self-managed cluster on EC2, virtual machines or bare metal.
- Practice installation, administration and troubleshooting without a managed control plane.

| Tool | Best use |
|---|---|
| kubeadm | Self-managed multi-node clusters and administration practice |
| Minikube | Local learning and development |
| Amazon EKS | AWS-managed Kubernetes control plane |

kubeadm requires you to manage infrastructure, runtime, networking, upgrades, backups and security. This lab has one control plane and is not highly available.

### How kubeadm works

```mermaid
flowchart LR
 A[Prepare nodes] --> B[kubeadm init on server]
 B --> C[Install CNI]
 C --> D[Generate join command]
 D --> E[kubeadm join on workers]
 E --> F[kubectl verify cluster]
```

See [technology stack and component roles](docs/technology-stack.md) and [platform comparison](difference.md).

## Repository layout

- [steps.md](steps.md) — quick checklist
- [docs/architecture.md](docs/architecture.md) — architecture and flow diagrams
- [docs/runtime.md](docs/runtime.md) — containerd compatibility and fallback
- [scripts/](scripts/) — node preparation, runtime, Kubernetes installation, initialization and verification
- [manifests/](manifests/) — Deployment, Service and DaemonSet exercises
- [difference.md](difference.md) — kubeadm vs EKS vs Minikube

## Architecture

```mermaid
flowchart TD
 U[Student - SSH] --> S
 U --> W1
 U --> W2
 subgraph AWS[AWS VPC - same subnet and security group]
 S[server - control plane]
 W1[worker1 - application pods]
 W2[worker2 - application pods]
 W1 -->|Join via private IP :6443| S
 W2 -->|Join via private IP :6443| S
 W1 <-->|Flannel pod network| W2
 end
```

| Node | Instance | Disk | Role |
|---|---|---|---|
| server | t3.large | 70 GiB | Manage cluster |
| worker1 | t3.medium | 50 GiB | Run applications |
| worker2 | t3.medium | 50 GiB | Run applications |

All nodes run Amazon Linux 2023, containerd and kubelet. Flannel connects pods using CIDR `10.244.0.0/16`.

[View component, installation and application diagrams](docs/architecture.md).

## Version compatibility (reviewed 24 November 2026)

- Kubernetes stable minor channel: **v1.37**; official release page lists v1.37.1 at review time. Install the newest available patch from this channel on all nodes.
- Containerd: **2.3.x or 2.4.x**, latest supported patch available (2.3.6 LTS / 2.4.1 active at review); see [upstream compatibility matrix](https://github.com/containerd/containerd/blob/main/RELEASES.md#kubernetes-support).
- Flannel: latest stable manifest from its official release page.
- Amazon Linux 2023: use the latest available AMI and review [AL2023 updates](https://docs.aws.amazon.com/linux/al2023/ug/managing-repos-os-updates.html).

If the Amazon Linux package repository does not supply a compatible containerd version, **stop before kubeadm init**. Install a compatible runtime following the [upstream installation guide](https://github.com/containerd/containerd/blob/main/docs/getting-started.md) (including runc, systemd service and CNI dependencies), or choose an OS/runtime combination supported by the matrix. Do not assume the distribution package is the latest upstream release.

## 1. Create EC2 instances — AWS Console

| Setting | server | worker1 | worker2 |
|---|---|---|---|
| AMI | Amazon Linux 2023, x86_64 | Same | Same |
| Instance | t3.large (2 vCPU / 8 GiB) | t3.medium (2 vCPU / 4 GiB) | t3.medium |
| Root EBS | 70 GiB | 50 GiB | 50 GiB |
| Key pair | `kubeadm.pem` | Same key | Same key |
| VPC / subnet | Same VPC and subnet | Same | Same |
| Security group | Dedicated cluster SG | Same | Same |

- Give each instance a different **Name**. A single subnet is easiest for this lab, but not a Kubernetes requirement.
- Nodes must reach package repositories and image registries (Internet Gateway/NAT as appropriate).
- Select a subnet/VPC CIDR **that does not overlap** the Flannel Pod CIDR `10.244.0.0/16`. Default AWS VPC `172.31.0.0/16` is fine.
- Set the security group's **inbound SSH TCP 22** source to **your own public IP (/32)**, not everyone.
- Add an inbound rule **All traffic / All protocols**, with **source = the cluster security group itself** (self-reference). This permits trusted node-to-node networking including API server TCP 6443 and Flannel VXLAN UDP 8472. **Never use 0.0.0.0/0 for All traffic.**
- Keep normal outbound access for package downloads and container image pulls. Do not open 6443 publicly.

### Values to record

```text
SERVER_PUBLIC_IP=...
SERVER_PRIVATE_IP=...
WORKER1_PUBLIC_IP=...
WORKER1_PRIVATE_IP=...
WORKER2_PUBLIC_IP=...
WORKER2_PRIVATE_IP=...
```

## 2. Connect — each EC2 instance

From your Mac/Linux terminal (or use EC2 Instance Connect):

```bash
chmod 400 kubeadm.pem
ssh -i kubeadm.pem ec2-user@<SERVER_PUBLIC_IP>
# Open a SECOND terminal:
ssh -i kubeadm.pem ec2-user@<WORKER1_PUBLIC_IP>
# Open a THIRD terminal:
ssh -i kubeadm.pem ec2-user@<WORKER2_PUBLIC_IP>
```

Replace angle-bracket placeholders with actual addresses; do not paste all three SSH commands into one EC2 session.

## 3. Set hostnames — ALL NODES (different command on each)

**On server**:

```bash
sudo hostnamectl set-hostname server
```

**On worker1**:

```bash
sudo hostnamectl set-hostname worker1
```

**On worker2**:

```bash
sudo hostnamectl set-hostname worker2
```

Verify on each: `hostnamectl --static`. Ensure each hostname resolves to the correct *private* IP through your network's DNS or by adding unique entries in `/etc/hosts` on **all three** nodes. Example (replace values):

```bash
sudo tee -a /etc/hosts <<'EOF'
<SERVER_PRIVATE_IP> server
<WORKER1_PRIVATE_IP> worker1
<WORKER2_PRIVATE_IP> worker2
EOF
```

## 4. OS and kernel preparation — ALL NODES

```bash
sudo dnf update -y
sudo dnf install -y curl tar conntrack-tools socat iproute-tc
# A reboot may be needed if the kernel was updated; reconnect afterward.
sudo swapoff -a
sudo sed -i.bak '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab

sudo tee /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
swapon --show
sysctl net.ipv4.ip_forward
```

`swapon --show` should print nothing; IP forwarding should be `1`.

## 5. Install containerd — ALL NODES

```bash
sudo dnf install -y containerd
containerd --version
# Review the printed version against the compatibility matrix above.
# Continue only with a compatible 2.3.x or 2.4.x runtime.
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
# Change the runtime cgroup driver (works with default 1.x/2.x generated configs)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
grep -n 'SystemdCgroup\|disabled_plugins' /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd
sudo systemctl is-active containerd
```

Expected: `SystemdCgroup = true`, with the CRI plugin **not disabled**, and the service `active`. Containerd 1.x and 2.x configuration sections differ; consult the [official container runtime guide](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) if `containerd`/CRI checks fail. Do not disable SELinux globally as a troubleshooting shortcut.

## 6. Install kubeadm, kubelet, kubectl — ALL NODES

This lab uses the Kubernetes **v1.37** RPM channel consistently across nodes. Choose another supported *minor* version only by changing the URL on **all three nodes** before installation.

```bash
sudo tee /etc/yum.repos.d/kubernetes.repo <<'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.37/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.37/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y kubelet kubeadm kubectl cri-tools kubernetes-cni --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

```

The kubelet may repeatedly restart until the node has been initialized/joined. That is expected. Do not run `kubeadm init` on workers.

### Verify installed versions — ALL NODES

Run these commands on the server and both workers before initializing the cluster. Confirm matching Kubernetes versions and a compatible container runtime.

```bash
cat /etc/os-release
containerd --version
kubeadm version
kubelet --version
kubectl version --client
rpm -q kubeadm kubelet kubectl
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock info
```

If containerd was installed from RPM, also run `rpm -q containerd`. An upstream binary installation will not have an RPM record.

## 7. Initialize cluster — SERVER ONLY

Check that `hostname -I` contains the server's correct VPC **private** IPv4 address. Set it explicitly:

```bash
SERVER_PRIVATE_IP="<SERVER_PRIVATE_IP>"
sudo kubeadm init \
  --kubernetes-version="$(kubeadm version -o short)" \
  --apiserver-advertise-address="$SERVER_PRIVATE_IP" \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

After `Your Kubernetes control-plane has initialized successfully!`, configure the current user:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
kubectl cluster-info
kubectl get nodes
```

The control plane is often `NotReady` until a Pod CNI is installed.

## 8. Install Flannel Pod networking — SERVER ONLY

Use **only one CNI**. The Pod CIDR used in `kubeadm init` above matches Flannel defaults.

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl get pods -n kube-flannel
kubectl get pods -n kube-system
```

For repeatable long-lived environments, pin a tested Flannel release rather than using `latest`. Do **not** add Calico after Flannel in this lab.

## 9. Generate worker join command — SERVER ONLY

```bash
sudo kubeadm token create --print-join-command
```

Example output (**example placeholders, not valid credentials**):

```bash
kubeadm join <SERVER_PRIVATE_IP>:6443 \
  --token <GENERATED_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<GENERATED_HASH>
```

Copy the **actual freshly generated** command from your server terminal. Token values expire; never commit active tokens to a public repository.

## 10. Join the cluster — WORKER1 and WORKER2 ONLY

On **each worker's own terminal**, paste the command from step 9, prefixing it with `sudo`:

```bash
sudo kubeadm join <SERVER_PRIVATE_IP>:6443 \
  --token <GENERATED_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<GENERATED_HASH>
```

Do not execute this sample literally. Use the real server IP/token/hash. Each worker should report successful joining. Workers do **not** need the server's `admin.conf`.

## 11. Verify — SERVER ONLY

```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
kubectl get pods -A -o wide
```

Expected eventually:

```text
NAME      STATUS   ROLES           AGE   VERSION
server    Ready    control-plane   ...   v1.37.x
worker1   Ready    <none>          ...   v1.37.x
worker2   Ready    <none>          ...   v1.37.x
```

Check `kubectl get nodes -o wide` to confirm each node has a **different private IP**.

## 12. Deploy and test applications — SERVER ONLY

```mermaid
flowchart LR
 C[curl on server] --> P[kubectl port-forward :8080]
 P --> S[nginx Service :80]
 S --> N[One ready Nginx pod]
```

Port-forward selects a backing pod through the Service; it does not expose the application publicly.

Use the provided YAML files for all application exercises. Do not create a second Deployment with the same name using imperative commands.

```bash
sudo dnf install -y git
git clone https://github.com/atulkamble/ec2-kubeadm.git
cd ec2-kubeadm
```

If already cloned, simply enter the existing repository directory.

| File | Purpose |
|---|---|
| manifests/deployment.yaml | Two Nginx replicas |
| manifests/service.yaml | Internal ClusterIP endpoint |
| manifests/daemonset.yaml | One Nginx pod per eligible node |

### A. Deploy

```bash
kubectl apply -f manifests/
kubectl rollout status deployment/nginx --timeout=180s
kubectl rollout status daemonset/nginx-per-node --timeout=180s
kubectl get deployments,daemonsets,services
kubectl get pods -o wide
```

### B. Test HTTP access

```bash
kubectl port-forward svc/nginx 8080:80
```

Open another SSH session to the server and run:

```bash
curl -I http://127.0.0.1:8080
```

Expected: HTTP 200. Stop port-forward with Ctrl+C in the original terminal. Deployment replicas may share a worker; the DaemonSet should run on both eligible workers.

## 13. Troubleshooting

| Symptom | Check |
|---|---|
| `kubeadm init` preflight error | `swapon --show`, containerd active, correct VPC private IP, sufficient resources |
| `kubeadm join` times out | Self-referencing cluster SG, TCP 6443 reachability, server API health |
| `container runtime is not running` | `sudo systemctl status containerd`; CRI plugin and cgroup settings |
| `NotReady` nodes | Flannel pods, `kubectl describe node <node>`, kernel modules and forwarding |
| `ContainerCreating` stuck | `kubectl describe pod <pod>`, `kubectl get pods -A`, CNI logs |
| Worker token expired | Run `sudo kubeadm token create --print-join-command` on server again |

Useful diagnostics:

```bash
# SERVER:
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl describe node worker1

# AFFECTED NODE:
sudo systemctl status containerd --no-pager
sudo systemctl status kubelet --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
```

Avoid resetting the cluster or rerunning `kubeadm init` until you've identified the error.

## 14. Cleanup and costs

```bash
# SERVER, if the example still exists:
kubectl delete -f manifests/ --ignore-not-found
```

To end the lab, terminate the EC2 instances and remove unused EBS volumes, public IPv4 allocations, and related paid resources as appropriate. Review the [official kubeadm teardown instructions](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down) before reusing nodes. EC2, EBS, and public IPv4 can generate charges.

## Optional automation

For a fresh cluster, use the [script-based guide](docs/automation.md) instead of manual steps 3–11. Do not run both methods. After joining the workers, return to step 12 to test the application.

## References

- [Kubernetes kubeadm installation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Kubernetes container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Kubernetes required ports](https://kubernetes.io/docs/reference/networking/ports-and-protocols/)
