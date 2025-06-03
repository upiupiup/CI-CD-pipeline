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

        stage('Deploy to Kubernetes') {
            steps {
                sh(script: '''
                    echo "Updating deployment.yaml with image tag: ${BUILD_ID} for image ${APP_NAME}"
                    # Pastikan hanya satu perintah sed yang efektif dan benar sesuai isi deployment.yaml
                    # Jika deployment.yaml memiliki 'image: carvilla:\${BUILD_ID}'
                    sed -i 's|image: ${APP_NAME}:\\\${BUILD_ID}|image: ${APP_NAME}:${BUILD_ID}|g' kubernetes/deployment.yaml
                    # Atau jika hanya mengganti placeholder \${BUILD_ID} di mana saja:
                    # sed -i 's|\\\${BUILD_ID}|${BUILD_ID}|g' kubernetes/deployment.yaml
                    # Pilih salah satu yang paling sesuai. Untuk sekarang, saya asumsikan yang pertama lebih aman.

                    echo "Applying Kubernetes manifests as user ubuntu..."
                    # GANTI PATH AKTUAL /usr/local/bin/kubectl JIKA PERLU
                    sudo -H -u ubuntu /usr/local/bin/kubectl apply -f kubernetes/deployment.yaml
                    SUDO_DEPLOY_EXIT_CODE=$?
                    if [ "${SUDO_DEPLOY_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl apply deployment failed with exit code ${SUDO_DEPLOY_EXIT_CODE}"
                        exit 1
                    fi

                    sudo -H -u ubuntu /usr/local/bin/kubectl apply -f kubernetes/service.yaml
                    SUDO_SERVICE_EXIT_CODE=$?
                    if [ "${SUDO_SERVICE_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl apply service failed with exit code ${SUDO_SERVICE_EXIT_CODE}"
                        exit 1
                    fi
                '''.stripIndent())
            }
        }

        stage('Verify Deployment') {
            steps {
                sh(script: '''
                    echo "Verifying deployment rollout status as user ubuntu..."
                    # GANTI PATH AKTUAL /usr/local/bin/kubectl JIKA PERLU
                    # Ganti 'carvilla-web' jika nama deploymentmu berbeda
                    sudo -H -u ubuntu /usr/local/bin/kubectl rollout status deployment/carvilla-web -n default
                    SUDO_ROLLOUT_EXIT_CODE=$?
                    if [ "${SUDO_ROLLOUT_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl rollout status failed with exit code ${SUDO_ROLLOUT_EXIT_CODE}"
                        exit 1
                    fi
                    
                    echo "Verifikasi deployment selesai."
                    echo "Untuk mengakses aplikasi, jalankan perintah ini di terminal EC2 sebagai user ubuntu:"
                    echo "minikube service <nama-service-carvilla> --url -p minikube" 
                    # Ganti <nama-service-carvilla> dengan nama service dari service.yaml
                '''.stripIndent())
            }
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
