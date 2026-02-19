kubectl delete deployment pgadmin -n ml-build
kubectl delete service pgadmin -n ml-build
kubectl delete pvc pgadmin-pvc -n ml-build  
kubectl delete secret pgadmin-secret -n ml-build
kubectl delete configmap pgadmin-config -n ml-build
