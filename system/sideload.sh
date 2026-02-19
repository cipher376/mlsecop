#!/bin/bash

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source-image> <new-tag>"
    echo "Example: $0 nginx:latest localhost/nginx:local"
    exit 1
fi

SOURCE_IMAGE=$1
NEW_TAG=$2
TMP_TAR="/tmp/sideload_image.tar"

# 1. Pull the image with Podman
echo "🚀 Pulling image: $SOURCE_IMAGE..."
podman pull "$SOURCE_IMAGE"

# 2. Retag the image
echo "🏷️ Retagging $SOURCE_IMAGE as $NEW_TAG..."
podman tag "$SOURCE_IMAGE" "$NEW_TAG"

# 3. Export image to a temporary tarball
echo "📦 Exporting to $TMP_TAR..."
podman save -o "$TMP_TAR" "$NEW_TAG"

# 4. Import into containerd k8s namespace
# Note: sudo is usually required to access containerd's socket
echo "📥 Importing to containerd (k8s.io namespace)..."
if sudo ctr -n k8s.io images import "$TMP_TAR"; then
    echo "✅ Success! Image $NEW_TAG is now available in Kubernetes."
else
    echo "❌ Error: Failed to import image to containerd."
    rm "$TMP_TAR"
    exit 1
fi

# 5. Cleanup
rm "$TMP_TAR"
echo "🧹 Temporary files cleaned up."