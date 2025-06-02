pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "registry.registry.svc.cluster.local:5000" // Sesuaikan jika menggunakan Docker Hub atau registry lain
        APP_NAME = "carvilla"
        // BUILD_ID adalah variabel bawaan Jenkins
    }

    stages {
        stage('Checkout & Preparation') {
            steps {
                // Kode sudah di-checkout oleh Jenkins SCM plugin ke workspace.
                echo "Kode di-checkout ke workspace: ${env.WORKSPACE}"
                sh "ls -la"  // Verifikasi isi workspace
            }
        }

        stage('Run Tests') {
            steps {
                // Pastikan skrip tes ada di ./tests/test.sh dan executable
                sh 'chmod +x tests/test.sh'
                sh './tests/test.sh'
            }
        }

        stage('Build Docker Image') {
            steps {
                // Membangun image. Tag ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID} harus sesuai
                // dengan yang diharapkan di kubernetes/deployment.yaml (setelah substitusi tag).
                echo "Building Docker image: ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID}"
                sh "docker build -t ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID} ."
                // Opsional: tag juga sebagai 'latest' untuk kemudahan atau jika service K8s merujuk 'latest'
                sh "docker build -t ${DOCKER_REGISTRY}/${APP_NAME}:latest ."
            }
        }

        stage('Push to Registry') {
            steps {
                // Tahap ini mengasumsikan DOCKER_REGISTRY adalah registry yang bisa dijangkau.
                // Jika ini Docker Hub atau registry privat, 'docker login' mungkin perlu
                // ditangani menggunakan 'withCredentials' sebelum push.
                echo "Pushing image to ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID}"
                sh "docker push ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_ID}"
                sh "docker push ${DOCKER_REGISTRY}/${APP_NAME}:latest" // Push tag 'latest' juga
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // Perintah sed ini menggantikan placeholder literal '\${BUILD_ID}' di deployment.yaml
                // dengan nilai BUILD_ID Jenkins saat ini.
                // Pastikan kubernetes/deployment.yaml memiliki image: <registry>/<appname>:\${BUILD_ID}
                echo "Updating deployment.yaml with tag: ${BUILD_ID}"
                sh "sed -i 's|\\\${BUILD_ID}|${BUILD_ID}|g' kubernetes/deployment.yaml"

                echo "Applying Kubernetes manifests..."
                sh "kubectl apply -f kubernetes/deployment.yaml"
                sh "kubectl apply -f kubernetes/service.yaml"
            }
        }

        stage('Verify Deployment') {
            steps {
                // Pastikan 'carvilla-web' adalah nama deployment yang benar di file deployment.yaml
                echo "Verifying deployment rollout status..."
                sh "kubectl rollout status deployment/carvilla-web -n default"
                echo "Verifikasi deployment selesai."
                echo "Untuk mengakses aplikasi, gunakan 'minikube service <nama-service-carvilla> --url' atau cek NodePort service."
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
        }
        success {
            echo "CI/CD pipeline completed successfully!"
        }
        failure {
            echo "CI/CD pipeline failed!"
        }
    }
}
