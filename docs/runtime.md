# Container runtime compatibility

Reviewed 24 November 2026: Kubernetes v1.37 recommends containerd 2.3.x or 2.4.x. The upstream matrix lists 2.3.6 (LTS) and 2.4.1 (active). AWS [AL2023 release 2023.12.20261117](https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.12.20261117.html) includes containerd 2.3.7-1.amzn2023.0.4. Prefer the AWS RPM over a manual upstream install. AL2023 locks repositories to the AMI release by default; for an older AMI upgrade explicitly using `sudo dnf upgrade --releasever=2023.12.20261117 -y` (only if older), reboot if needed, then install containerd. Do not downgrade newer AMIs.

On all nodes:
```bash
sudo dnf list --showduplicates containerd
containerd --version
```
If the Amazon Linux package is incompatible, stop. For a fresh x86_64 lab, an upstream installation is an alternative: follow the official [containerd install guide](https://github.com/containerd/containerd/blob/main/docs/getting-started.md), select the linux-amd64 archive from the [2.3.6 release](https://github.com/containerd/containerd/releases/tag/v2.3.6), verify the published checksum, and install its compatible runc and the upstream systemd unit as documented. Do not mix a distribution service and an upstream binary without checking PATH and ExecStart. Confirm /opt/cni/bin is the CNI binary directory; install Kubernetes CNI packages as described in step 3. Retain SELinux protections and resolve policy errors with the distribution guidance. On fresh dedicated nodes run scripts/02-install-runtime.sh after installation.

```bash
command -v containerd
containerd --version
sudo systemctl cat containerd
sudo systemctl status containerd --no-pager
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock info
```

References: [compatibility matrix](https://github.com/containerd/containerd/blob/main/RELEASES.md#kubernetes-support), [Kubernetes runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/).
