helm repo add bitnami https://charts.bitnami.com/bitnami
helm install gitlab-db bitnami/postgresql -n ml-build \
  --set primary.nodeSelector.workload=build-jobs \
  --set auth.database=gitlabhq_production \
  --set auth.username=gitlab \
-f values.yaml
