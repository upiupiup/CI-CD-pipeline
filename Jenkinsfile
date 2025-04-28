pipeline {
    agent {
        kubernetes {
            yaml """
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: docker
                image: docker:20.10.14-dind
                command:
                - sleep
                args:
                - 99d
                securityContext:
                  privileged: true
                volumeMounts:
                - name: docker-socket
                  mountPath: /var/run/docker.sock
              - name: kubectl
                image: bitnami/kubectl:latest
                command:
                - sleep
                args:
                - 99d
              volumes:
              - name: docker-socket
                hostPath:
                  path: /var/run/docker.sock
            """
        }
    }
    
    environment {
        DOCKER_REGISTRY = 'registry.registry.svc.cluster.local:5000'  // Local registry
        DOCKER_IMAGE = 'web-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = 'default'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    sh "docker build -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ."
                    sh "docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                container('docker') {
                    sh "docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                    sh "docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
                    # Update deployment image
                    kubectl apply -f k8s/deployment.yaml
                    kubectl set image deployment/web-app web-app=${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} -n ${K8S_NAMESPACE}
                    kubectl rollout status deployment/web-app -n ${K8S_NAMESPACE}
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('kubectl') {
                    sh """
                    # Wait for deployment to stabilize
                    sleep 10
                    
                    # Check if pods are running
                    kubectl get pods -l app=web-app -n ${K8S_NAMESPACE}
                    
                    # Check service details
                    kubectl get svc web-app -n ${K8S_NAMESPACE}
                    
                    echo "Application deployed successfully! Access at http://10.34.7.115:30080"
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "Deployment completed successfully! Application is available at http://10.34.7.115:30080"
        }
        failure {
            echo "Deployment failed! Check logs for details."
        }
    }
}
