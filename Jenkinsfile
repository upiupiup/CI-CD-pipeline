pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = "registry.registry.svc.cluster.local:5000"
        APP_NAME = "carvilla"
        LOCAL_REPO_PATH = "/home/widhi/git-repos/CI-CD-pipeline"
    }
    
    stages {
        stage('Checkout') {
            steps {
                // For a local repository, we can either:
                // 1. Skip checkout if Jenkins can access the local directory
                // 2. Use a shared directory approach
                dir("${env.LOCAL_REPO_PATH}") {
                    sh "ls -la"  // Just to verify we can access the local directory
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                dir("${env.LOCAL_REPO_PATH}") {
                    sh 'chmod +x tests/test.sh'
                    sh './tests/test.sh'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                dir("${env.LOCAL_REPO_PATH}") {
                    sh "docker build -t ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID} ."
                }
            }
        }
        
        // Rest of stages remain the same but also use dir() if needed
        stage('Push to Registry') {
            steps {
                dir("${env.LOCAL_REPO_PATH}") {
                    sh "docker push ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID}"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                dir("${env.LOCAL_REPO_PATH}") {
                    sh "sed -i 's|\\${BUILD_ID}|${BUILD_ID}|g' kubernetes/deployment.yaml"
                    sh "kubectl apply -f kubernetes/deployment.yaml"
                    sh "kubectl apply -f kubernetes/service.yaml"
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh "kubectl rollout status deployment/carvilla-web -n default"
                echo "Application deployed and accessible at http://10.34.7.115:40000"
            }
        }
    }
    
    post {
        success {
            echo "CI/CD pipeline completed successfully!"
        }
        failure {
            echo "CI/CD pipeline failed!"
        }
    }
}