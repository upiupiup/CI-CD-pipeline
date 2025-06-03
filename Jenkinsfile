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
                sh(script: '''
                    echo "Updating deployment.yaml with image tag: ${BUILD_ID} for image ${APP_NAME}"
                    sed -i 's|image: ${APP_NAME}:\\\${BUILD_ID}|image: ${APP_NAME}:${BUILD_ID}|g' kubernetes/deployment.yaml

                    echo "Applying Kubernetes manifests as user ubuntu..."
                    sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/deployment.yaml  # <--- PATH KUBECTL DIPERBARUI
                    SUDO_DEPLOY_EXIT_CODE=$?
                    if [ "${SUDO_DEPLOY_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl apply deployment failed with exit code ${SUDO_DEPLOY_EXIT_CODE}"
                        exit 1
                    fi

                    sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/service.yaml    # <--- PATH KUBECTL DIPERBARUI
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
                    # Ganti 'carvilla-web' jika nama deploymentmu berbeda
                    sudo -H -u ubuntu /usr/bin/kubectl rollout status deployment/carvilla-web -n default # <--- PATH KUBECTL DIPERBARUI
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
