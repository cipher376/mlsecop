helm upgrade --install cilium cilium/cilium  \
  --namespace kube-system \
  --version 1.18.5 \
  -f ~/mlsecop/cilium/values.yaml

  cilium status --wait