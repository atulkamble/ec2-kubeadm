#!/usr/bin/env bash
set -euo pipefail
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
kubectl wait --for=condition=Ready node/server node/worker1 node/worker2 --timeout=300s
kubectl get pods -A -o wide
kubectl rollout status deployment/coredns -n kube-system --timeout=300s
