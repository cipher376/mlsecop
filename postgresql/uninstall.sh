helm uninstall gitlab-db-postgresql -n ml-build


kubectl delete configmaps -l release=gitlab-db-postgresql -n ml-build
kubectl get pvc -n ml-build
