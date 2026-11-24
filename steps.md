# Quick Steps — EC2 kubeadm (1 server + 2 workers)

Full copy/paste commands and troubleshooting: **[README.md](README.md)**.

| Order | Run on | Action |
|---|---|---|
| 1 | AWS Console | Launch **server (t3.large, 70 GiB)**, **worker1** and **worker2 (t3.medium, 50 GiB each)** with Amazon Linux 2023 and one `kubeadm.pem` key pair |
| 2 | AWS Console | Same VPC, same subnet, same dedicated SG. SSH TCP/22 only from your IP. Inbound **All traffic from the SG itself**, never from the public internet |
| 3 | All 3 nodes | SSH using `ssh -i kubeadm.pem ec2-user@<PUBLIC_IP>`; assign unique hostnames and working private IP resolution |
| 4 | All 3 nodes | `dnf update`, disable swap, enable overlay/br_netfilter and IP forwarding |
| 5 | All 3 nodes | Install **containerd**, set `SystemdCgroup = true`, enable containerd service |
| 6 | All 3 nodes | Configure Kubernetes v1.36 RPM repo, install **kubeadm + kubelet + kubectl**, enable kubelet |
| 7 | Server only | `sudo kubeadm init --apiserver-advertise-address=<SERVER_PRIVATE_IP> --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock` |
| 8 | Server only | Copy `/etc/kubernetes/admin.conf` to `$HOME/.kube/config`, correct ownership |
| 9 | Server only | Install **Flannel CNI**; do not combine CNIs |
| 10 | Server only | Generate **fresh** command: `sudo kubeadm token create --print-join-command` |
| 11 | Worker1 and worker2 | Run `sudo kubeadm join ...` with the **actual** output from the server |
| 12 | Server only | Verify all **3 nodes Ready** and check system pods |
| 13 | Server only | Deploy test Nginx workload, inspect placement and clean up |

## Verification (server)

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
kubectl get pods -A -o wide
```

Expected: `server`, `worker1`, and `worker2` all report `Ready`.

## Core commands (server)

```bash
# After all-node preparation detailed in README:
sudo kubeadm init \
  --apiserver-advertise-address=<SERVER_PRIVATE_IP> \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock

mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sudo kubeadm token create --print-join-command
```

**Workers:** paste the resulting `kubeadm join` command with `sudo`, once on each worker.

> The angle-bracket placeholders must be replaced. Never publish live join tokens. Refer to [README.md](README.md) for all required prerequisite commands and troubleshooting.
