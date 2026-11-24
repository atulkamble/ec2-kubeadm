# Architecture diagrams

## 1. EC2 cluster

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

## 2. Kubernetes components

```mermaid
flowchart TD
 K[kubectl] --> A
 subgraph S[Control plane - server]
 A[API server] <--> E[etcd]
 SC[Scheduler] --> A
 CM[Controller manager] --> A
 end
 subgraph W[Each worker]
 L[kubelet] --> R[containerd]
 R --> P[Application pods]
 end
 L <--> A
```

The API server receives requests, etcd stores state, the scheduler selects nodes, and kubelet asks containerd to run containers.

## 3. Installation flow

```mermaid
flowchart TD
 A[Create and connect to EC2] --> B[Prepare all three nodes]
 B --> C[Install containerd and Kubernetes]
 C --> D[Initialize server]
 D --> E[Install Flannel]
 E --> F[Generate join command]
 F --> G[Join both workers]
 G --> H[Verify three Ready nodes]
 H --> I[Deploy YAML and test HTTP]
```

## 4. Application testing

```mermaid
flowchart TD
 M[kubectl apply -f manifests/] --> D[Deployment - 2 replicas]
 M --> S[ClusterIP Service]
 M --> DS[DaemonSet]
 D --> P1[Nginx pod]
 D --> P2[Nginx pod]
 S --> P1
 S --> P2
 DS --> W1[One pod on worker1]
 DS --> W2[One pod on worker2]
```

Deployment pods may run on either worker. The Service selects Deployment pods, not DaemonSet pods. The control plane is normally tainted to prevent ordinary workloads from scheduling there.

Follow [README.md](../README.md) for the complete practical. This single-control-plane cluster is for training, not high availability.
