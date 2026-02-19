#!/bin/bash

# label-worker-nodes.sh



echo "🏷️  Starting labeling process for MLSecOps workers..."



# 1. Label the ML node for production models

kubectl label node worker-node-ml workload=production --overwrite
kubectl label node worker-node-ml tier=worker --overwrite
echo "✅ worker-node-ml labeled as ml-production"



# 2. Label the OpsSec node for security tools and monitoring
kubectl label node worker-node-opssec tier=vault-protected --overwrite 
kubectl label node worker-node-opssec workload=security --overwrite
kubectl taint nodes worker-node-opssec tier=vault-protected:NoSchedule-
echo "✅ worker-node-opssec labeled as opssec"



# 3. Label the Build node for GitLab, Registry, and DBs

kubectl label node worker-node-build workload=build-jobs --overwrite
kubectl label node worker-node-build tier=pipeline --overwrite
echo "✅ worker-node-build labeled as build-jobs"



# 4. Label the Master node for vault
kubectl label node master-node node-role.kubernetes.io/master=true --overwrite
kubectl label node master-node tier=control --overwrite

echo "----------------------------------------------------"

echo "📊 Current Cluster Workload Distribution:"

kubectl get nodes -o custom-columns=NAME:.metadata.name,WORKLOAD:.metadata.labels.workload,TIER:.metadata.labels.tier
