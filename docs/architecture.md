# Architecture and execution flow

```mermaid
flowchart TD
  A[Administrator via SSH] --> S
  subgraph VPC[AWS VPC - same subnet and cluster security group]
    S[server: API server / etcd / scheduler / controller manager]
    W1[worker1: kubelet / containerd / pods]
    W2[worker2: kubelet / containerd / pods]
    W1 -->|TCP 6443| S
    W2 -->|TCP 6443| S
    W1 <-->|Flannel VXLAN UDP 8472| W2
  end
```

```mermaid
flowchart TD
  A[Launch three EC2 instances] --> B[Prepare all nodes]
  B --> C[Install compatible containerd]
  C --> D[Install Kubernetes components]
  D --> E[Initialize server]
  E --> F[Configure kubectl and Flannel]
  F --> G[Generate join command]
  G --> H[Join both workers]
  H --> I[Verify three Ready nodes]
  I --> J[Deploy and test Nginx]
```

The cluster is self-managed and has a single control-plane failure point. The default control-plane taint prevents ordinary workloads from scheduling there. This is a lab, not an HA production design.
