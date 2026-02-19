#!/bin/bash
# install-minio.sh
#helm upgrade --install gitlab-minio bitnami/minio -n ml-build \
#  --set image.repository=bitnami/minio \
#  --set image.tag=latest \
#  --set auth.rootUser=admin \
#  --set auth.rootPassword=mlsecops-minio-pass \
#  --set persistence.size=20Gi \
#  --set nodeSelector.workload=build-jobs \
#  --set defaultBuckets="registry;lfs;artifacts;uploads;packages;terraform-state;ci-cache" \
#  --set sidecars={} \
#  --set service.ports.console=9001


# 1. Purge the old failed state one last time
helm uninstall gitlab-minio -n ml-build
kubectl delete deployment gitlab-minio -n ml-build --ignore-not-found

# 2. Install using the clean file
helm install gitlab-minio bitnami/minio -n ml-build --debug -v 10 \
-f ~/mlsecop/minIO/values.yaml
