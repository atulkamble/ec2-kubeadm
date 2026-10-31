# Kubernetes kubeadm Cluster on AWS EC2 (Amazon Linux 2023)

Practical three-node cluster lab based on the commands executed on 31 October 2026.

## 1. Lab topology

| Role | Hostname | EC2 instance | Private IP | Public IP | Size |
|---|---|---|---|---|---|
| Control plane | `k8s-master` | `i-052600c025c873882` | `172.31.22.55` | `18.212.237.144` | t2.large |
| Worker | `worker1` | `i-0d50e74c4cd0d5c3e` | `172.31.17.104` | `100.53.134.22` | t3.medium |
| Worker | `worker2` | `i-0c77cb01d37ea0811` | `172.31.27.217` | `98.84.165.48` | t3.medium |

- AWS Region: **us-east-1** (N. Virginia); AZ: **us-east-1d**
- EC2 SSH key pair: **kubeadm** (private key file `kubeadm.pem`)
- Kubernetes package repository: **v1.36**
- Container runtime: **containerd**
- Pod CIDR in this clean procedure: **10.244.0.0/16**
- Pod networking: **Flannel only** (do not also deploy Calico)
- Your instance's EC2 security group was named `launch-wizard-1`. Adjust its rules carefully before testing.

> **Important:** These are lab IP addresses from the recorded session, not static templates. Replace them if EC2 instances are rebuilt. All three instances must have private connectivity. Prefer SSH access from your own IP only, and allow Kubernetes node-to-node traffic only within the trusted cluster security group. Avoid exposing port 6443 or kubelet ports publicly.

## 2. EC2 networking

Use one VPC (for example `10.0.0.0/16`), a subnet with sufficient IP addresses, and route tables that allow private communication. A public subnet with an Internet Gateway can simplify downloading packages in a lab; production nodes should normally be placed in private subnets with suitable outbound access.

### Security group guidance

| Traffic | Port / protocol | Source | Purpose |
|---|---|---|---|
| SSH | TCP 22 | Your workstation IP / bastion only | Administration |
| API server | TCP 6443 | Cluster node SG / permitted administrators | Worker-to-control-plane Kubernetes API |
| etcd | TCP 2379-2380 | Control-plane SG only | etcd (when applicable) |
| Kubelet API | TCP 10250 | Cluster node SG | Kubelet API |
| kube-scheduler | TCP 10259 | Control plane only | Local control-plane component |
| kube-controller-manager | TCP 10257 | Control plane only | Local control-plane component |
| NodePort (optional) | TCP 30000-32767 | Approved lab clients only | NodePort Services |
| Flannel VXLAN | UDP 8472 | Cluster node SG only | Pod overlay connectivity |

For this **lab**, a simple alternative is to permit all traffic **between members of the same dedicated cluster SG**, not from `0.0.0.0/0`. The relevant ports are subject to the selected CNI and actual control-plane topology. Check the [Kubernetes required ports](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) documentation.

## 3. Connect to instances

From your workstation, substitute the correct public IP of each instance:

```bash
chmod 400 kubeadm.pem
ssh -i kubeadm.pem ec2-user@18.212.237.144
ssh -i kubeadm.pem ec2-user@100.53.134.22
ssh -i kubeadm.pem ec2-user@98.84.165.48
```

## 4. Prepare all three nodes

Execute on **master, worker1, and worker2** (using their respective SSH sessions).

### A. Hostnames

Run **only one** matching command on each node:

```bash
# master only
sudo hostnamectl set-hostname k8s-master

# worker1 only
sudo hostnamectl set-hostname worker1

# worker2 only
sudo hostnamectl set-hostname worker2
```

Add host-to-private-IP mapping on **all nodes**:

```bash
sudo tee -a /etc/hosts <<'EOF'
172.31.22.55 k8s-master
172.31.17.104 worker1
172.31.27.217 worker2
EOF
```

### B. System, swap and networking configuration

```bash
cat /etc/os-release
hostnamectl
hostname -I
nproc
free -h
lsblk

sudo dnf update -y
sudo swapoff -a
sudo sed -i.bak '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab
swapon --show

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
lsmod | grep br_netfilter
sysctl net.ipv4.ip_forward
```

### C. Install and configure containerd

```bash
sudo dnf install -y containerd
containerd --version

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Confirm a systemd cgroup driver and that CRI is NOT disabled
grep -n 'disabled_plugins\|SystemdCgroup' /etc/containerd/config.toml

sudo systemctl enable --now containerd
sudo systemctl restart containerd
sudo systemctl is-active containerd
```

Containerd configuration layouts differ in versions 1.x and 2.x; check the [Kubernetes container runtime guide](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) if the setting is missing or the CRI socket is unavailable.

### D. Install kubeadm, kubelet and kubectl

```bash
sudo tee /etc/yum.repos.d/kubernetes.repo <<'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.36/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.36/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

kubeadm version
kubelet --version
kubectl version --client
```

> The kubelet may restart or fail its health checks before the node has been initialized or joined. This is normal during initial setup. Check containerd and kernel networking prerequisites if join preflight fails. SELinux changes are not universally necessary; review your specific environment instead of disabling security controls indiscriminately.

## 5. Initialize the control plane (master only)

```bash
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "$PRIVATE_IP"

sudo kubeadm init \
  --apiserver-advertise-address="$PRIVATE_IP" \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Look for `Your Kubernetes control-plane has initialized successfully!`.

Configure access for `ec2-user`:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

kubectl cluster-info
kubectl get nodes
```

The node can remain `NotReady` until the CNI is installed.

## 6. Install the pod network (master only)

**Choose only one CNI.** The recorded session installed Flannel and later attempted a Calico operator installation. That is **not a recommended installation sequence**. This reproducible guide chooses **Flannel**, with matching `10.244.0.0/16` pod CIDR.

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

kubectl get pods -A
kubectl get nodes -o wide
```

For reproducible production setups, pin a reviewed Flannel release rather than `latest`.

### If choosing Calico instead on a brand-new cluster

**Do not execute these commands after installing Flannel.** Initialize the new control plane with an appropriate non-overlapping pod CIDR and apply Calico manifests with an `ipPools[].cidr` that matches it. For Kubernetes 1.36, the Calico v3.33.0 operator CRD manifest is `v3_projectcalico_org.yaml`, **not** the `-v1beta1.yaml` variant shown in the session history.

See [Calico installation documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/helm) and review the operator resource definitions before applying them.

## 7. Join worker nodes

On **master**, create a **new** join command instead of reusing a token from a terminal history:

```bash
sudo kubeadm token create --print-join-command
```

On **each worker**, run the **fresh command** printed above with sudo. The general form is:

```bash
sudo kubeadm join 172.31.22.55:6443 \
  --token <NEW_JOIN_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<NEW_CA_CERT_HASH>
```

The command includes sensitive join credentials; do not publish live values in public GitHub files.

On master, verify:

```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl get pods -A
```

Expected cluster node names: `k8s-master`, `worker1`, `worker2`; all should eventually be `Ready`.

## 8. Nginx Deployment practice

On master:

```bash
kubectl create deployment mydeployment --image=nginx
kubectl get deployments
kubectl get pods
kubectl get pods -o wide
```

The recorded lab showed `mydeployment-76957f9675-fwcnl` running on `worker1`.

## 9. Nginx DaemonSet practice

`kubectl create daemonset mydaemonset --image=nginx` is **not** supported by `kubectl create`. Use a manifest instead.

```bash
cat > daemonset.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mydaemonset
spec:
  selector:
    matchLabels:
      app: mydaemonset
  template:
    metadata:
      labels:
        app: mydaemonset
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
EOF

kubectl apply -f daemonset.yaml
kubectl get daemonsets
kubectl get pods -o wide
kubectl describe daemonset mydaemonset
```

**Observed result from the original lab:**

```text
NAME                 READY   STATUS    NODE
mydaemonset-vdb6j    1/1     Running   worker1
mydaemonset-vdb84    1/1     Running   worker2
```

A DaemonSet normally maintains a pod on every **eligible** node. With a standard kubeadm control-plane taint, these Nginx pods ran on the two worker nodes rather than the master.

## 10. Troubleshooting checks

```bash
# On master
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl describe node worker1
kubectl describe node worker2
kubectl -n kube-system get pods
kubectl get daemonset -A

# On any problematic worker
sudo systemctl enable --now kubelet
sudo systemctl status kubelet
sudo systemctl status containerd
sudo journalctl -u kubelet -n 100 --no-pager

# Test access to master API (on worker)
nc -vz 172.31.22.55 6443
```

If worker join gets stuck during preflight, confirm EC2 security group rules, the API server's health, worker-to-master TCP 6443 connectivity, containerd CRI support, swap settings and kubelet logs. Do not repeatedly run `kubeadm join` or reset nodes without inspecting the actual error first.

If pods remain `ContainerCreating` or nodes remain `NotReady`, verify the chosen single CNI and inspect the associated CNI pods/logs.

## 11. Optional cleanup

```bash
kubectl delete -f daemonset.yaml
kubectl delete deployment mydeployment
```

To fully dismantle a disposable lab cluster, follow the official [kubeadm cleanup steps](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down) on each node before terminating EC2 instances.

## Reference

- [Install kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Create a kubeadm cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

> Cost reminder: EC2 instances, storage and public IPv4 addresses may incur AWS charges even when no applications are running. Stop/terminate disposable lab resources when finished.
