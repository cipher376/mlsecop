export REDIS_PASSWORD=$(kubectl get secret --namespace ml-build gitlab-redis-secret \
  -o jsonpath="{.data.redis-password}" | base64 -d)

echo "Redis Password: $REDIS_PASSWORD"

# Test Redis connection
kubectl run redis-client --rm -it --restart=Never \
  --namespace ml-build \
  --image docker.io/bitnami/redis:7.2 -- \
  redis-cli -h redis-master -a $REDIS_PASSWORD