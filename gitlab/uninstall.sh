helm uninstall gitlab -n ml-build




kubectl delete configmaps -l release=gitlab -n ml-build

# Verify the PVC names first
kubectl get pvc -n ml-build
kubectl delete pvc repo-data-gitlab-gitaly-0   -n ml-build
kubectl delete pvc gitlab-minio -n ml-build
kubectl delete cnp gitlab-to-postgress-allow -n ml-build