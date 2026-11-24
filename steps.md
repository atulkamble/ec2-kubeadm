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
