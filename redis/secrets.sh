# 1. Redis Secret for gitlab radis
kubectl create secret generic gitlab-redis-secret \
  -n ml-build --from-literal=redis-password=mlsecops-redis-pass \
  --dry-run=client -o yaml | kubectl create -f -
