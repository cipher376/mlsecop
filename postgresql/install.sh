helm repo add bitnami https://charts.bitnami.com/bitnami

helm install gitlab-db-posgresql bitnami/postgresql -n ml-build  -f ~/mlsecop/postgresql/values.yaml
