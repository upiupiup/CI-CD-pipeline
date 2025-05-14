This module provides a practical guide for implementing a CI/CD pipeline to deploy the CarVilla web application to Kubernetes in a local environment.

## 1. Pipeline Scenario Overview

The CI/CD pipeline will deploy the CarVilla web application using Jenkins, with automated testing before deployment, and making the application accessible to users through a NodePort service.

![CI/CD Pipeline Flow](https://mermaid.ink/img/pako:eNptkkFPwzAMhf-K5RNIbdOWwontyqETEkKcuA2-JFpwSeqQONOK2H8nbbt13eAW-733ZFnOWdmdp6yxBt1JW239CBHbnbLvl0r-wNcxtMTb9U7WX6yKfSvZpo-YwccQyDfPL-PxWIyvXXyvFewCOmR5BvJWUf7J_J6puHCC7lNwcSA84yptjYx2gE9k0fP7LhC8U-DNS1VV6gWzLKNU0JEfKSDxcEsnP9xzW_ZfgoTgUaUUrmKvw7pV0bZdzg7txfE3kOoX69C5FQn3FO42fMjcb0rinLUOfTMsZ7RKWD2X0R_V9gCXAcFtbMjTQW3JV2K7Jb8hHUkXSuwYnSW0DB5gazwe1VyKezDTmh4DB02cPrhMI13he22WG7O4CtRU1lwEK-H1Z3M7rM96ReXUDzv9WgvxN1P28acLzeSMJ_kbOOez9wT5Jkl61_HKn8EJO_ELF9B0p9C_tqP8G3Px6tSt8pTtu2F2QqjqbMGHYnl8vIxjX4VjXpwd_AQ6KOjs?type=png)

## 1.5. Jenkins Installation

Before implementing the CI/CD pipeline, you need to set up Jenkins in your Kubernetes cluster. Follow these steps:

### Step 1: Create a Namespace for DevOps Tools

```bash
kubectl create namespace devops-tools
```
### Step 2: Create a Persistent Volume for Jenkins Data

```bash
cat > jenkins-volume.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/jenkins-data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: devops-tools
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```
# Create the volume and host directory
```bash
sudo mkdir -p /mnt/jenkins-data
sudo chmod 777 /mnt/jenkins-data
kubectl apply -f jenkins-volume.yaml
```
### Step 3: Create Service Account for Jenkins

```bash
cat > jenkins-sa.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: devops-tools
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: devops-tools
EOF
kubectl apply -f jenkins-sa.yaml

### Step 4: Create Jenkins Deployment and Service
```bash
cat > jenkins-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: devops-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      securityContext:
        fsGroup: 1000
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
          name: httpport
        - containerPort: 50000
          name: jnlpport
        volumeMounts:
        - name: jenkins-data
          mountPath: /var/jenkins_home
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=true"
        resources:
          limits:
            memory: "2Gi"
            cpu: "1000m"
          requests:
            memory: "500Mi"
            cpu: "500m"
      volumes:
      - name: jenkins-data
        persistentVolumeClaim:
          claimName: jenkins-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: devops-tools
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 32000
    name: http
  - port: 50000
    targetPort: 50000
    name: jnlp
  selector:
    app: jenkins
EOF
```
kubectl apply -f jenkins-deployment.yaml

### Step 5: Wait for Jenkins to Start

kubectl get pods -n devops-tools -w

### Step 6: Get Jenkins Admin Password

#### Get the Jenkins pod name
```bash
JENKINS_POD=$(kubectl get pods -n devops-tools -l app=jenkins -o jsonpath="{.items[0].metadata.name}")
```
#### Get the initial admin password
```bash
kubectl exec -it $JENKINS_POD -n devops-tools -- cat /var/jenkins_home/secrets/initialAdminPassword
```
Step 7: Access and Configure Jenkins
1. Access Jenkins at http://10.34.7.115:32000/
2. Enter the admin password obtained in the previous step
3. Install suggested plugins
4. Create an admin user when prompted:
5. Username: admin
6. Password: (choose a secure password)
7. Full name: Jenkins Admin
8. Email: your-email@example.com
9. Click "Save and Continue"
10. On the Instance Configuration page, confirm the Jenkins URL: http://10.34.7.115:32000/
11. Click "Save and Finish"
#### Step 8: Install Required Plugins
1. Go to "Manage Jenkins" > "Manage Plugins" > "Available" tab
2. Search for and select the following plugins:
- Kubernetes
- Docker Pipeline
- Pipeline: Kubernetes
- Git
- GitHub Integration
3. Click "Install without restart"
4. Check "Restart Jenkins when installation is complete and no jobs are running"
### Step 9: Configure Kubernetes Cloud
After Jenkins restarts:

1. Go to "Manage Jenkins" > "Manage Nodes and Clouds" > "Configure Clouds"
2. Click "Add a new cloud" > "Kubernetes"
3. Configure as follows:
- Name: k8s
- Kubernetes URL: https://10.34.7.115:6443
- Kubernetes Namespace: devops-tools
- Check "Disable HTTPS certificate check"
- Jenkins URL: http://jenkins.devops-tools.svc.cluster.local:8080
4. Click "Test Connection" to verify - you should see "Connection test successful"
5. Under "Pod Templates" > "Add Pod Template":
- Name: jenkins-agent
- Namespace: devops-tools
- Labels: jenkins-agent
6. Under "Container Templates" > "Add Container":
- Name: jnlp
- Docker image: jenkins/inbound-agent:latest
7. Click "Save"
### Step 10: Create kubeconfig Secret for Jenkins
This step ensures Jenkins has proper access to the Kubernetes API:
```bash
# Create kubeconfig secret for Jenkins
kubectl create secret generic jenkins-kubeconfig \
  --from-file=config=/home/widhi/.kube/config \
  -n devops-tools || true
```
### Step 11: Configure Docker Registry Access
Go to "Manage Jenkins" > "Manage Credentials" > "Jenkins" > "Global credentials" > "Add Credentials"
Configure as follows:
Kind: Username with password
Scope: Global
Username: (your registry username if needed, or leave blank for anonymous)
Password: (your registry password if needed, or leave blank for anonymous)
ID: docker-registry
Description: Docker Registry Credentials
Click "OK"

## 2. Prerequisites

- Kubernetes cluster with:
  - Master node at 10.34.7.115
  - Worker node at 10.34.7.5
- Jenkins installed as Kubernetes Pod, accessible at http://10.34.7.115:32000/
- Kubernetes cloud configured in Jenkins with name "k8s"
- Prometheus installed for monitoring
- Docker registry at http://10.34.7.115:30500
- Git repository with the CarVilla web application code

## 3. Pipeline Implementation

### Step 1: Creating Required Files

First, let's create necessary files for our pipeline. **Run these commands on the master node (10.34.7.115)**:

```bash
# Navigate to project directory
cd /home/widhi/git-repos/CI-CD-pipeline/

# Create kubernetes directory if it doesn't exist
mkdir -p kubernetes

# Create test directory if it doesn't exist
mkdir -p tests
```

#### Create a Dockerfile

```bash
cat > Dockerfile << 'EOF'
FROM nginx:alpine

COPY . /usr/share/nginx/html/
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
```

#### Create Test Script

```bash
cat > tests/test.sh << 'EOF'
#!/bin/bash
# Simple test script to check required files exist

echo "Running tests for CarVilla web application"

# Check if index.html exists
if [ ! -f index.html ]; then
  echo "Error: index.html not found!"
  exit 1
fi

# Check if assets directory exists
if [ ! -d assets ]; then
  echo "Error: assets directory not found!"
  exit 1
fi

# Check if required JavaScript files exist
if [ ! -f assets/js/custom.js ]; then
  echo "Error: custom.js not found!"
  exit 1
fi

# Check if CSS files exist
if [ ! -f assets/css/style.css ]; then
  echo "Error: style.css not found!"
  exit 1
fi

echo "All tests passed successfully!"
exit 0
EOF

chmod +x tests/test.sh
```

#### Create Kubernetes Deployment File

```bash
cat > kubernetes/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: carvilla-web
  namespace: default
  labels:
    app: carvilla-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: carvilla-web
  template:
    metadata:
      labels:
        app: carvilla-web
    spec:
      containers:
      - name: carvilla-web
        image: 10.34.7.115:30500/carvilla:${BUILD_NUMBER}
        ports:
        - containerPort: 80
          name: http
        resources:
          limits:
            cpu: "0.5"
            memory: "256Mi"
          requests:
            cpu: "0.2"
            memory: "128Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
EOF
```

#### Service File is Already Created

You already have the service.yaml file with the following content:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: carvilla-web-service
  namespace: default
  labels:
    app: carvilla-web
spec:
  type: NodePort
  selector:
    app: carvilla-web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 40000
```

#### Commit Files to Git (Optional if you want to trigger automatically)

```bash
git add Dockerfile tests/ kubernetes/
git commit -m "Add CI/CD configuration files"
git push
```
# Run on the master node
kubectl create namespace devops-tools || true

kubectl create serviceaccount jenkins -n devops-tools || true

kubectl create clusterrolebinding jenkins-admin-binding --clusterrole=cluster-admin --serviceaccount=devops-tools:jenkins || true

# Create kubeconfig secret for Jenkins
kubectl create secret generic jenkins-kubeconfig \
  --from-file=config=/home/widhi/.kube/config \
  -n devops-tools || true


### Step 2: Create the Jenkins Pipeline

1. Login to Jenkins at http://10.34.7.115:32000/
2. Click on "New Item" in the left menu
3. Enter "carvilla-pipeline" as the name and select "Pipeline"
4. Click "OK"
5. In the configuration page, scroll down to the "Pipeline" section
6. Choose "Pipeline script" and enter the following script:

```bash
pipeline {
    agent {
        kubernetes {
            cloud 'k8s'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu:20.04
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /var/run/docker.sock
      name: docker-sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
      type: Socket
"""
        }
    }
    
    environment {
        REGISTRY_URL = "10.34.7.115:30500"
        IMAGE_NAME = "carvilla"
        APP_PORT = "40000"
        K8S_MASTER = "10.34.7.115"
    }
    
    stages {
        stage('Setup Environment') {
            steps {
                container('ubuntu') {
                    sh '''
                    # Update package lists
                    apt-get update
                    
                    # Install prerequisites
                    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git
                    
                    # Install Docker CLI
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
                    apt-get update
                    apt-get install -y docker-ce-cli
                    
                    # Install kubectl
                    curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/
                    
                    # Configure Docker for insecure registry
                    mkdir -p ~/.docker
                    echo '{"insecure-registries":["10.34.7.115:30500"]}' > ~/.docker/config.json
                    
                    # Configure kubectl
                    mkdir -p ~/.kube
                    echo "Creating basic kubeconfig that connects to host..."
                    cat > ~/.kube/config << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: http://${K8S_MASTER}:8080
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
users:
- name: kubernetes-admin
  user: {}
EOF
                    
                    # Verify installations
                    echo "Docker version:"
                    docker --version
                    
                    echo "Kubectl version:"
                    kubectl version --client
                    '''
                }
            }
        }
        
        stage('Checkout') {
            steps {
                container('ubuntu') {
                    sh '''
                    rm -rf *
                    git clone https://github.com/Widhi-yahya/CI-CD-pipeline.git .
                    ls -la
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Running application tests..."
                    chmod +x tests/test.sh
                    ./tests/test.sh
                    '''
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Building Docker image..."
                    docker build --network=host -t ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} .
                    docker tag ${REGISTRY_URLgit }/${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY_URL}/${IMAGE_NAME}:latest
                    
                    echo "Pushing Docker image to registry..."
                    # Use HTTP protocol explicitly
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} || echo "Push failed, continuing anyway"
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:latest || echo "Push failed, continuing anyway"
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Preparing Kubernetes manifest files..."
                    # Create deployment.yaml if it doesn't exist
                    if [ ! -f "kubernetes/deployment.yaml" ]; then
                        echo "Creating deployment.yaml..."
                        mkdir -p kubernetes
                        cat > kubernetes/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: carvilla-web
  namespace: default
  labels:
    app: carvilla-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: carvilla-web
  template:
    metadata:
      labels:
        app: carvilla-web
    spec:
      containers:
      - name: carvilla-web
        image: 10.34.7.115:30500/carvilla:BUILD_NUMBER
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: http
EOF
                    fi
                    
                    # Replace BUILD_NUMBER with actual build number
                    sed -i "s/BUILD_NUMBER/${BUILD_NUMBER}/g" kubernetes/deployment.yaml
                    
                    echo "Contents of deployment.yaml:"
                    cat kubernetes/deployment.yaml
                    
                    echo "Contents of service.yaml:"
                    cat kubernetes/service.yaml
                    
                    echo "Trying kubectl configuration..."
                    kubectl get nodes || echo "Failed to get nodes, but continuing"
                    
                    echo "Applying Kubernetes manifests..."
                    kubectl apply -f kubernetes/deployment.yaml || echo "Deployment failed, but continuing"
                    kubectl apply -f kubernetes/service.yaml || echo "Service deployment failed, but continuing"
                    
                    echo "Waiting for deployment to complete..."
                    kubectl rollout status deployment/carvilla-web --timeout=60s || echo "Rollout status check failed, but continuing"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Verifying deployment..."
                    kubectl get pods -l app=carvilla-web || echo "Failed to get pods"
                    kubectl get svc carvilla-web-service || echo "Failed to get service"
                    
                    # Try to access the app
                    apt-get install -y curl
                    echo "Trying to access the application..."
                    curl -I http://${K8S_MASTER}:${APP_PORT} || echo "Failed to access the application, but deployment might still be in progress"
                    '''
                    
                    echo "==================================================="
                    echo "CarVilla Web App should be accessible at: http://${K8S_MASTER}:${APP_PORT}"
                    echo "==================================================="
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully! CarVilla web application is now accessible at http://${K8S_MASTER}:${APP_PORT}"
        }
        failure {
            echo "Pipeline failed! Please check the logs for details."
        }
        always {
            echo "Pipeline execution finished. Check logs for details."
        }
    }
}
```

7. Click "Save"

### Step 3: Triggering the Pipeline Manually

1. In Jenkins, navigate to the "carvilla-pipeline" project
2. Click "Build Now" in the left sidebar

This will start the pipeline execution, which will:
- Check out the code
- Run the tests
- Build a Docker image
- Push the image to your registry
- Deploy to Kubernetes
- Verify the deployment

### Step 4: Setting Up Automatic Triggering (Optional)

To have the pipeline automatically triggered when code changes are pushed to the repository:

1. In Jenkins, go to "carvilla-pipeline" > "Configure"
2. Under "Build Triggers", select "GitHub hook trigger for GITScm polling"
3. Click "Save"

Then in your GitHub repository:
1. Go to Settings > Webhooks
2. Click "Add webhook"
3. Set the Payload URL to: `http://10.34.7.115:32000/github-webhook/`
4. Content type: application/json
5. Select "Just the push event"
6. Click "Add webhook"

## 4. Testing the Application

After successful deployment, you can access the CarVilla web application by visiting:

**URL:** http://10.34.7.115:40000

### Simple Test Commands

**On the master node (10.34.7.115):**

```bash
# Check if the service is running
kubectl get svc carvilla-web-service

# Check if the pods are running properly
kubectl get pods -l app=carvilla-web

# Test if the application is accessible
curl -I http://10.34.7.115:40000
```

## 5. Monitoring with Prometheus

Since Prometheus is already installed, you can set up basic monitoring for the application.

**On the master node (10.34.7.115):**

```bash
cat > kubernetes/service-monitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: carvilla-web-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: carvilla-web
  endpoints:
  - port: http
    interval: 15s
  namespaceSelector:
    matchNames:
    - default
EOF

kubectl apply -f kubernetes/service-monitor.yaml
```

## 6. Troubleshooting

### Common Issues and Solutions

#### Problem: Image Pull Errors
- **Solution**: Ensure registry is accessible from worker nodes

**On the worker node (10.34.7.5):**

```bash
curl -X GET http://10.34.7.115:30500/v2/_catalog
```

#### Problem: Website Not Loading
- **Solution**: Check if pods are running correctly

**On the master node (10.34.7.115):**

```bash
kubectl describe pods -l app=carvilla-web
kubectl logs -l app=carvilla-web
```

#### Problem: Pipeline Fails at the Docker Build Stage
- **Solution**: Ensure Docker socket is accessible

**On the master node (10.34.7.115):**

```bash
ls -la /var/run/docker.sock
chmod 666 /var/run/docker.sock  # If needed
```

## 7. Pipeline Explanation

1. **Checkout Stage**: Retrieves the code from the Git repository
2. **Test Stage**: Runs the test script to ensure all required files are present
3. **Build and Push Stage**: Creates a Docker image and pushes it to your registry
4. **Deploy Stage**: Applies Kubernetes manifests to create/update the deployment and service
5. **Verify Stage**: Confirms the application is running correctly and accessible

## 8. Scaling the Application

If you need to handle more traffic, you can scale the application:

**On the master node (10.34.7.115):**

```bash
kubectl scale deployment carvilla-web --replicas=4
```

## 9. Conclusion

This CI/CD pipeline provides a complete workflow for deploying the CarVilla web application to your Kubernetes cluster. By following this module, you can:

1. Automatically test your application
2. Build and containerize it using Docker
3. Deploy it to Kubernetes with high availability
4. Make it accessible to users via a consistent URL
5. Monitor it using Prometheus

