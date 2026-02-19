helm uninstall vault -n ml-security
# Delete the Persistent Volume Claim
kubectl delete pvc data-vault-0 -n ml-security
# Delete the injector webhook
kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg

# Delete the RBAC roles
kubectl delete clusterrole vault-agent-injector-clusterrole
kubectl delete clusterrolebinding vault-agent-injector-binding
kubectl patch pvc data-vault-0 -n ml-security -p '{"metadata":{"finalizers":null}}'
kubectl get all -n ml-security