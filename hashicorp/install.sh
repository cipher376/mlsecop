#!/bin/bash

#try uninstalling
~/mlsecop/hashicorp/uninstall.sh

# Add the repo if you haven't
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install into your specific security namespace
helm install  vault hashicorp/vault \
  -n ml-security \
  -f ~/mlsecop/hashicorp/values.yaml


# Initialize and capture the keys!
#kubectl exec -it vault-0 -n ml-security -- vault operator init

# Unseal (Repeat 3 times with different keys)
#kubectl exec -it vault-0 -n ml-security -- vault operator unseal


#let the vault talk to kube api
#kubectl exec -it vault-0 -n ml-security -- /bin/sh

# Login with your Root Token first
#vault login <YOUR_ROOT_TOKEN>

# Enable the k8s auth engine
#vault auth enable kubernetes

# Configure Vault to talk to your K3s API
#vault write auth/kubernetes/config \
#    kubernetes_host="https://kubernetes.default.svc:443"
