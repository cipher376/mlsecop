# Check pods
kubectl get pods -n postgres

# Expected for standalone:
# postgresql-0   1/1   Running   0   2m

# Expected for HA:
# postgresql-postgresql-0   1/1   Running   0   2m
# postgresql-postgresql-1   1/1   Running   0   2m
# postgresql-postgresql-2   1/1   Running   0   2m
# postgresql-pgpool-xxx     1/1   Running   0   2m

# Get PostgreSQL password
export POSTGRES_PASSWORD=$(kubectl get secret --namespace ml-build gitlab-db-postgresql-secret \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

echo "PostgreSQL Password: $POSTGRES_PASSWORD"

# Test PostgreSQL connection
kubectl run postgresql-client --rm -it --restart=Never \
  --namespace ml-build \
  --image bitnami/postgresql \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host gitlab-db-posgresql-postgresql  -U postgres -d gitlabhq_production -p 5432