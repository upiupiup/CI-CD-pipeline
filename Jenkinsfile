pipeline {
    agent any

    environment {
        // DOCKER_REGISTRY tidak lagi digunakan untuk push, tapi nama image tetap penting
        APP_NAME = "carvilla"
        // BUILD_ID adalah variabel bawaan Jenkins
    }

    stages {
        stage('Checkout & Preparation') {
            steps {
                echo "Kode di-checkout ke workspace: ${env.WORKSPACE}"
                sh "ls -la"
            }
        }

        stage('Run Tests') {
            steps {
                sh 'chmod +x tests/test.sh'
                sh './tests/test.sh'
            }
        }

        stage('Build Docker Image for Minikube') {
            steps {
                // Mengatur environment Docker agar menunjuk ke Docker daemon Minikube
                // Perhatikan bahwa '-p minikube' mungkin diperlukan jika profil Minikube-mu bukan default 'minikube'
                // Jika Minikube profile default, cukup 'eval $(minikube docker-env)'
                // Untuk Jenkins, lebih aman menjalankan ini di dalam sh block
                sh '''
                    eval $(minikube -p minikube docker-env)
                    echo "Building Docker image: ${APP_NAME}:${BUILD_ID}"
                    docker build -t ${APP_NAME}:${BUILD_ID} .
                    echo "Tagging image ${APP_NAME}:${BUILD_ID} as ${APP_NAME}:latest"
                    docker tag ${APP_NAME}:${BUILD_ID} ${APP_NAME}:latest
                '''
                // Catatan: 'docker build' dua kali mungkin tidak efisien jika tidak ada perubahan.
                // Cukup 'docker tag ${APP_NAME}:${BUILD_ID} ${APP_NAME}:latest' setelah build pertama.
                // Saya perbaiki di bawah untuk lebih efisien.
            }
        }
        
        // Tahap 'Push to Registry' bisa di-skip atau dihapus jika menggunakan Minikube docker-env
        /*
        stage('Push to Registry') {
            steps {
                echo "Skipping push to registry as image is built in Minikube's Docker daemon"
            }
        }
        */

        stage('Deploy to Kubernetes') {
            steps {
                // Pastikan deployment.yaml menggunakan nama image yang benar (tanpa registry prefix)
                // dan imagePullPolicy: IfNotPresent atau Never
                // Contoh: image: carvilla:${BUILD_ID}
                //         imagePullPolicy: IfNotPresent
                //
                // Perintah sed ini menggantikan placeholder '\${BUILD_ID}' di deployment.yaml
                // dengan nilai BUILD_ID Jenkins saat ini.
                echo "Updating deployment.yaml with image tag: ${BUILD_ID} for image ${APP_NAME}"
                // Pastikan sed command ini sesuai dengan format image di deployment.yaml-mu
                // Contoh jika deployment.yaml punya: image: carvilla:\${BUILD_ID}
                sh "sed -i 's|image: ${APP_NAME}:\\\${BUILD_ID}|image: ${APP_NAME}:${BUILD_ID}|g' kubernetes/deployment.yaml"
                // Atau jika hanya mengganti tag setelah nama image yang fix:
                // sh "sed -i 's|${APP_NAME}:.*|${APP_NAME}:${BUILD_ID}|g' kubernetes/deployment.yaml"
                // Atau yang lebih spesifik:
                sh "sed -i 's|\\\${BUILD_ID}|${BUILD_ID}|g' kubernetes/deployment.yaml"


                echo "Applying Kubernetes manifests..."
                sh "kubectl apply -f kubernetes/deployment.yaml"
                sh "kubectl apply -f kubernetes/service.yaml"
            }
        }

        stage('Verify Deployment') {
            steps {
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
