# Optional automated setup

Use this instead of manual steps 3–11 in [README](../README.md). First create and connect to the three EC2 instances using steps 1–2.

On each fresh node:
```bash
sudo dnf install -y git
git clone https://github.com/atulkamble/ec2-kubeadm.git
cd ec2-kubeadm
sudo bash scripts/01-prepare-node.sh server
sudo bash scripts/02-install-runtime.sh
sudo bash scripts/03-install-kubernetes.sh
```
Replace server with worker1 or worker2 on the corresponding machine. Reconnect after a required reboot before continuing. If runtime compatibility fails, stop and follow [runtime.md](runtime.md).

On server only:
```bash
bash scripts/04-init-server.sh SERVER_PRIVATE_IP
```
Replace SERVER_PRIVATE_IP with the actual private IP. Run the generated join command with sudo on both workers.

On server:
```bash
bash scripts/05-verify-cluster.sh
```

Continue with [README step 12](../README.md#12-deploy-and-test-applications--server-only) for application deployment and testing. Do not repeat manual initialization.
