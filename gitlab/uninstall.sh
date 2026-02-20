helm uninstall gitlab -n ml-build


# Verify the PVC names first
kubectl get secret -n ml-build -l release=gitlab | grep gitlab | awk '{print $1}' | xargs -I {} kubectl delete secret {} -n ml-build
kubectl get pvc -n ml-build -l release=gitlab | grep gitlab | awk '{print $1}' | xargs -I {} kubectl delete pvc {} -n ml-build
kubectl get configmaps -n ml-build -l release=gitlab | grep gitlab | awk '{print $1}' | xargs -I {} kubectl delete configmap {} -n ml-build
