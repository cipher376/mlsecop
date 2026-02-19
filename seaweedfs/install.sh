
#uninstall 
~/mlsecop/seaweedfs/uninstall.sh

# helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
# helm repo update

# 2. Install SeaweedFS
helm upgrade --install seaweedfs seaweedfs/seaweedfs -n ml-build \
-f ~/mlsecop/seaweedfs/values.yaml
