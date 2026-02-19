vault policy write gitlab-policy - <<EOF
path "secret/data/postgres" {
  capabilities = ["read"]
}
EOF


vault write auth/kubernetes/role/gitlab-role \
    bound_service_account_names=default \
    bound_service_account_namespaces=ml-build \
    policies=gitlab-policy \
    ttl=24h
