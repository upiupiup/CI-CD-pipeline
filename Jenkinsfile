pipeline {
    agent any

    environment {
        APP_NAME = "carvilla"
    }

    stages {
        stage('Checkout & Preparation') {
            steps {
                echo "Kode sudah di-checkout ke workspace: ${env.WORKSPACE}"
                sh "ls -la"
            }
        }

        stage('Run Tests') {
            steps {
                sh 'chmod +x tests/test.sh'
                sh './tests/test.sh'
            }
        }

        stage('Build Docker Image in Minikube') {
            steps {
                sh '''
                    echo "--- Setting Docker Env to Minikube ---"
                    eval $(minikube -p minikube docker-env)

                    echo "Building Docker image: ${APP_NAME}:${BUILD_ID}"
                    docker build -t ${APP_NAME}:${BUILD_ID} .
                    docker tag ${APP_NAME}:${BUILD_ID} ${APP_NAME}:latest
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    echo "Replacing IMAGE_TAG_PLACEHOLDER with ${BUILD_ID}"
                    sed -i "s|IMAGE_TAG_PLACEHOLDER|${BUILD_ID}|g" kubernetes/deployment.yaml

                    echo "--- Applying deployment.yaml ---"
                    kubectl apply -f kubernetes/deployment.yaml

                    echo "--- Applying service.yaml ---"
                    kubectl apply -f kubernetes/service.yaml
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "--- Verifying deployment rollout ---"
                    kubectl rollout status deployment/carvilla-web -n default

                    echo "Deployment verified successfully."
                    echo "Akses dari browser: http://$(minikube ip):<NodePort>"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
        }
        success {
            echo "✅ CI/CD pipeline completed successfully!"
        }
        failure {
            echo "❌ CI/CD pipeline failed!"
        }
    }
}
