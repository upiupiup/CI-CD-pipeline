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
                    sh(script: '''
                        echo "--- Debugging minikube docker-env ---"
                        
                        echo "Verifying Minikube status (running as ubuntu via sudo):"
                        # GANTI PATH AKTUAL JIKA PERLU
                        sudo -H -u ubuntu /usr/local/bin/minikube status
                        MINIKUBE_STATUS_EXIT_CODE=$?
                        if [ "${MINIKUBE_STATUS_EXIT_CODE}" -ne 0 ]; then
                            echo "Minikube status command failed with exit code ${MINIKUBE_STATUS_EXIT_CODE}"
                            exit 1
                        fi
                        
                        echo "Attempting to get minikube docker-env (running as ubuntu via sudo):"
                        # GANTI PATH AKTUAL JIKA PERLU
                        MINIKUBE_DOCKER_ENV_COMMANDS=$(sudo -H -u ubuntu /usr/local/bin/minikube -p minikube docker-env | grep "^export")
                        MINIKUBE_DOCKER_ENV_EXIT_CODE=$?
                        
                        echo "Exit code of 'minikube -p minikube docker-env': ${MINIKUBE_DOCKER_ENV_EXIT_CODE}"
                        echo "Output of 'minikube -p minikube docker-env' (export lines only):"
                        echo "${MINIKUBE_DOCKER_ENV_COMMANDS}"
                        
                        if [ "${MINIKUBE_DOCKER_ENV_EXIT_CODE}" -eq 0 ] && [ -n "${MINIKUBE_DOCKER_ENV_COMMANDS}" ]; then
                            echo "Attempting Docker build and tag as user ubuntu..."
                            
                            # Buat string perintah yang akan dijalankan oleh sh -c
                            # ${MINIKUBE_DOCKER_ENV_COMMANDS} akan berisi beberapa baris "export VAR=VAL"
                            # APP_NAME dan BUILD_ID adalah variabel environment Jenkins yang sudah ada
                            
                            # Perlu escape karakter khusus jika APP_NAME atau BUILD_ID mengandungnya, tapi biasanya tidak.
                            # Pastikan variabel Jenkins ${APP_NAME} dan ${BUILD_ID} diekspansi oleh Groovy, bukan oleh shell di dalam sudo.
                            
                            # Kita akan inject perintah export langsung ke dalam script yang dijalankan sudo
                            # dan pastikan path docker juga absolut
                            
                            sudo -H -u ubuntu sh -c " \\
                                ${MINIKUBE_DOCKER_ENV_COMMANDS} && \\
                                echo 'Docker environment should now be set for user ubuntu.' && \\
                                echo 'DOCKER_HOST is: ' \$DOCKER_HOST && \\
                                echo 'Building Docker image: ${APP_NAME}:${BUILD_ID}' && \\
                                /usr/bin/docker build -t '${APP_NAME}:${BUILD_ID}' . && \\
                                echo 'Tagging image ${APP_NAME}:${BUILD_ID} as ${APP_NAME}:latest' && \\
                                /usr/bin/docker tag '${APP_NAME}:${BUILD_ID}' '${APP_NAME}:latest' \\
                            "
                            SUDO_DOCKER_EXIT_CODE=$?
                            
                            if [ "${SUDO_DOCKER_EXIT_CODE}" -ne 0 ]; then
                                echo "Docker build/tag commands failed with exit code ${SUDO_DOCKER_EXIT_CODE}"
                                exit 1
                            fi
                        else
                            echo "Skipping docker build due to minikube docker-env failure or empty output."
                            exit 1 
                        fi
                        echo "--- End Debugging ---"
                    '''.stripIndent()) // stripIndent penting untuk blok sh multi-baris
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
