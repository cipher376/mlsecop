#!/bin/bash
# install-redis.sh
#helm repo add bitnami https://charts.bitnami.com/bitnami
#helm repo update

helm upgrade --install gitlab-redis bitnami/redis -n ml-build  \
  --set global.storageClass=local-path \
  --set master.nodeSelector.workload=build-jobs \
  --set replica.replicaCount=0 \
  --set auth.enabled=true \
  --set auth.password=mlsecops-redis-pass \
  --set secret=gitlab-redis-secret \
-f ~/mlsecop/redis/values.yaml
