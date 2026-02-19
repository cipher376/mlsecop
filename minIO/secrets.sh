#MinIO (S3) Connection Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-minio-secret
  namespace: ml-build
stringData:
  config: |
    provider: AWS
    region: us-east-1
    aws_access_key_id: admin
    aws_secret_access_key: mlsecops-minio-pass
    host: gitlab-minio.ml-build.svc.cluster.local
    endpoint: http://gitlab-minio.ml-build.svc.cluster.local:9000
    path_style: true
EOF
