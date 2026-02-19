helm repo add jetstack https://charts.jetstack.io --force-update

 kubectl annotate crd \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  meta.helm.sh/release-name- \
  meta.helm.sh/release-namespace-


  kubectl label crd \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  app.kubernetes.io/managed-by-


  kubectl annotate crd \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  meta.helm.sh/release-name="cert-manager" \
  meta.helm.sh/release-namespace="ml-security" \
  --overwrite
  kubectl label crd \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  app.kubernetes.io/managed-by="Helm" \
  --overwrite
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace ml-security \
  --set crds.enabled=true

  kubectl apply -f ~/mlsecop/cilium/cert-issuer.yaml

 