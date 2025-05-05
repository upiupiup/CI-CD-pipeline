#!/bin/bash
# Deployment script for CarVilla web application

# Parse input
if [ $# -lt 1 ]; then
  echo "Usage: $0 <build_number>"
  echo "Example: $0 15"
  exit 1
fi

BUILD_NUMBER=$1
REPO_DIR="/home/widhi/git-repos/CI-CD-pipeline"
cd $REPO_DIR

echo "Deployment started for build #${BUILD_NUMBER}"

# Check if the image exists in the registry
echo "Checking if image exists in registry..."
if curl -s -f http://10.34.7.115:30500/v2/carvilla/manifests/${BUILD_NUMBER} > /dev/null; then
  echo "Image exists in registry"
else
  echo "Warning: Image not found in registry. It might not have been pushed successfully."
  echo "Do you want to continue with deployment? (y/n)"
  read -r answer
  if [[ "$answer" != "y" ]]; then
    echo "Deployment aborted."
    exit 1
  fi
  echo "Continuing with deployment..."
fi

# Update deployment file with build number
sed -i "s|\${BUILD_NUMBER}|${BUILD_NUMBER}|g" kubernetes/deployment.yaml

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

# Wait for deployment
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/carvilla-web --timeout=60s || true

# Verify deployment
echo "Verifying deployment..."
kubectl get pods -l app=carvilla-web
kubectl get svc carvilla-web-service

echo "CarVilla Web App is now accessible at: http://10.34.7.115:40000"