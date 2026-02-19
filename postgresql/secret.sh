kubectl create secret generic gitlab-db-postgresql-secret \
  --from-literal=postgres-password="My-p0stGr3sql_P4ss_admin" \
  --from-literal=password="My-p0stGr3sql_P4ss_user" \
  -n ml-build
