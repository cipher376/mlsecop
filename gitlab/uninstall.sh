helm uninstall gitlab -n ml-build

# Verify the PVC names first
kubectl get pvc -n ml-build


kubectl delete configmaps -l release=gitlab -n ml-build