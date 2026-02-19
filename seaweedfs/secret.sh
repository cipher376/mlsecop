cat <<EOF > connection.yaml
provider: AWS
aws_access_key_id: admin
aws_secret_access_key: mlsecops-seaweed-pass
aws_signature_version: 4
endpoint: http://seaweedfs-s3.ml-build.svc.cluster.local:8333
path_style: true
region: us-east-1
EOF

kubectl create secret generic gitlab-seaweedfs-db-secret \
  --from-file=connection=connection.yaml \
  -n ml-build --dry-run=client -o yaml | kubectl apply -f -
