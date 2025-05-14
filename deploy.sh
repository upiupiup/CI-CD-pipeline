#!/bin/bash
# Deployment script for CarVilla web application

# Parse input
if [ $# -lt 1 ]; then
  echo "Usage: $0 <build_number> [rebuild]"
  echo "Example: $0 19"
  echo "Add 'rebuild' as second parameter to force rebuilding the image locally"
  exit 1
fi

BUILD_NUMBER=$1
REBUILD=${2:-no}
REPO_DIR="/home/widhi/git-repos/CI-CD-pipeline"
REGISTRY="10.34.7.115:30500"
IMAGE_NAME="carvilla"
K8S_SERVER="https://10.34.7.115:6443"  # Explicitly set K8s API server

cd $REPO_DIR

echo "Deployment started for build #${BUILD_NUMBER}"

# Check if we need to rebuild or if the image exists in the registry
NEED_REBUILD="no"
if [[ "$REBUILD" == "rebuild" ]]; then
  NEED_REBUILD="yes"
  echo "Rebuild flag specified, will build image locally"
else
  echo "Checking if image exists in registry..."
  if curl -s -f "http://${REGISTRY}/v2/${IMAGE_NAME}/manifests/${BUILD_NUMBER}" > /dev/null; then
    echo "Image exists in registry"
  else
    echo "Warning: Image not found in registry. It might not have been pushed successfully."
    echo "Do you want to build the image locally? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
      NEED_REBUILD="yes"
    else
      echo "Do you want to continue with deployment anyway? (y/n)"
      read -r answer
      if [[ "$answer" != "y" ]]; then
        echo "Deployment aborted."
        exit 1
      fi
      echo "Continuing with deployment..."
    fi
  fi
fi

# Build image locally if needed
if [[ "$NEED_REBUILD" == "yes" ]]; then
  echo "Building Docker image locally..."
  docker build -t ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} .
  docker tag ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY}/${IMAGE_NAME}:latest
  
  echo "Do you want to push the locally built image to the registry? (y/n)"
  read -r answer
  if [[ "$answer" == "y" ]]; then
    echo "Pushing image to registry..."
    docker push ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
    docker push ${REGISTRY}/${IMAGE_NAME}:latest
  fi
fi

# Update deployment file with build number
echo "Updating deployment manifest with build number ${BUILD_NUMBER}..."
sed -i "s|\${BUILD_NUMBER}|${BUILD_NUMBER}|g" kubernetes/deployment.yaml

# Apply Kubernetes manifests with explicit server
echo "Applying Kubernetes manifests..."
kubectl --server=${K8S_SERVER} apply -f kubernetes/deployment.yaml
kubectl --server=${K8S_SERVER} apply -f kubernetes/service.yaml

# Wait for deployment
echo "Waiting for deployment to complete..."
kubectl --server=${K8S_SERVER} rollout status deployment/carvilla-web --timeout=60s || echo "Rollout may not be complete, continuing..."

# Verify deployment
echo "Verifying deployment..."
kubectl --server=${K8S_SERVER} get pods -l app=carvilla-web
kubectl --server=${K8S_SERVER} get svc carvilla-web-service

echo "CarVilla Web App is now accessible at: http://10.34.7.115:40000"