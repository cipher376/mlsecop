#Uninstall 
helm uninstall seaweedfs -n ml-build --wait || true
kubectl delete pvc -n ml-build -l app.kubernetes.io/name=seaweedfs --ignore-not-found
kubectl delete secret -n ml-build -l owner=helm,name=seaweedfs --ignore-not-found
