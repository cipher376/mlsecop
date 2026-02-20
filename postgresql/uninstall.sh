helm uninstall gitlab-db-postgresql -n ml-build


kubectl delete configmaps -l release=gitlab-db-postgresql -n ml-build
kubectl get pvc -n ml-build | grep gitlab-db-postgresql | awk '{print $1}' | xargs -I {} kubectl delete pvc {} -n ml-build
kubectl get secret -n ml-build | grep gitlab-db-postgresql | awk '{print $1}' | xargs -I {} kubectl delete secret {} -n ml-build