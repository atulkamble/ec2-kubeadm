```
create k8s cluster (1 server, 2 worker) using kubeadm 

ref: https://github.com/atulkamble/ec2-kubeadm

1. create server, 2 worker nodes
- same vpc, same subnet, same SG 
SG - All traffic, ssh 
amazon linux - 50GB/70GB, large/medium

2. configurations - commands 
3. kubectl, kubelet, kubeadm install 
4. server node - connection >> token generate (command*)
5. worker nodes >> connect >>  paste (command*)

kubectl get nodes -o wide
kubectl get pods -n kube-system

```
