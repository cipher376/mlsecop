helm upgrade --install cilium cilium/cilium  \
  --namespace kube-system \
  --version 1.18.5 \
  -f ~/mlsecop/cilium/values.yaml

  cilium status --wait

  kubectl apply -f ~/mlsecop/cilium/gateway.yaml
  kubectl apply -f ~/mlsecop/cilium/cert-issuer.yaml
  ~/mlsecop/cilium/cert-manager-nstall.sh