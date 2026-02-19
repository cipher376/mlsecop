helm repo add gitlab https://charts.gitlab.io
helm upgrade --install standalone-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --create-namespace \
  -f ~/mlsecop/gitlab/runner-values.yaml