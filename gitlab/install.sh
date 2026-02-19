helm upgrade --install gitlab gitlab/gitlab \
  -n ml-build \
  -f ~/mlsecop/gitlab/values.yaml 
  
  
kubectl apply -f ~/mlsecop/gitlab/policy.yaml
