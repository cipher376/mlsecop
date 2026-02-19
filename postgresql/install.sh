#helm repo add bitnami https://charts.bitnami.com/bitnami

helm upgrade --install gitlab-db-postgresql bitnami/postgresql -n ml-build  -f ~/mlsecop/postgresql/values.yaml
# helm upgrade gitlab-db-postgresql bitnami/postgresql -n ml-build  -f ~/mlsecop/postgresql/values.yaml
