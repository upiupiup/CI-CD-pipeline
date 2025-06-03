// Jenkinsfile - Versi dengan Placeholder Sederhana di deployment.yaml
pipeline {
    agent any

    environment {
        APP_NAME = "carvilla"
        // BUILD_ID adalah variabel bawaan Jenkins, kita akan gunakan env.BUILD_ID
    }

    stages {
        stage('Checkout & Preparation') {
            steps {
                echo "Kode sudah di-checkout ke workspace: ${env.WORKSPACE}"
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

        stage('Build Docker Image for Minikube') {
            steps {
                sh(script: """
                    echo "--- Debugging minikube docker-env ---"
                    
                    echo "Verifying Minikube status (running as ubuntu via sudo):"
                    sudo -H -u ubuntu /usr/local/bin/minikube status # Ganti path jika output 'which minikube' berbeda
                    MINIKUBE_STATUS_EXIT_CODE=\$?
                    if [ "\${MINIKUBE_STATUS_EXIT_CODE}" -ne 0 ]; then
                        echo "Minikube status command failed with exit code \${MINIKUBE_STATUS_EXIT_CODE}"
                        exit 1 # Keluar dari sh step jika gagal
                    fi
                    
                    echo "Attempting to get minikube docker-env (running as ubuntu via sudo):"
                    MINIKUBE_DOCKER_ENV_COMMANDS=\$(sudo -H -u ubuntu /usr/local/bin/minikube -p minikube docker-env | grep "^export") # Ganti path jika perlu
                    MINIKUBE_DOCKER_ENV_EXIT_CODE=\$?
                    
                    echo "Exit code of 'minikube -p minikube docker-env': \${MINIKUBE_DOCKER_ENV_EXIT_CODE}"
                    echo "Output of 'minikube -p minikube docker-env' (export lines only):"
                    echo "\${MINIKUBE_DOCKER_ENV_COMMANDS}"
                    
                    if [ "\${MINIKUBE_DOCKER_ENV_EXIT_CODE}" -eq 0 ] && [ -n "\${MINIKUBE_DOCKER_ENV_COMMANDS}" ]; then
                        echo "Attempting Docker build and tag as user ubuntu..."
                        
                        # Eksekusi semua perintah Docker dalam satu blok sudo sh -c
                        sudo -H -u ubuntu sh -c " \\
                            \${MINIKUBE_DOCKER_ENV_COMMANDS} && \\
                            echo 'Docker environment should now be set for user ubuntu.' && \\
                            echo 'DOCKER_HOST is: '\$DOCKER_HOST && \\
                            echo 'Building Docker image: ${env.APP_NAME}:${env.BUILD_ID}' && \\
                            /usr/bin/docker build -t '${env.APP_NAME}:${env.BUILD_ID}' . && \\
                            echo 'Tagging image ${env.APP_NAME}:${env.BUILD_ID} as ${env.APP_NAME}:latest' && \\
                            /usr/bin/docker tag '${env.APP_NAME}:${env.BUILD_ID}' '${env.APP_NAME}:latest' \\
                        " # Ganti path /usr/bin/docker jika output 'which docker' berbeda
                        SUDO_DOCKER_EXIT_CODE=\$?
                        
                        if [ "\${SUDO_DOCKER_EXIT_CODE}" -ne 0 ]; then
                            echo "Docker build/tag commands failed with exit code \${SUDO_DOCKER_EXIT_CODE}"
                            exit 1 # Keluar dari sh step jika gagal
                        fi
                    else
                        echo "Skipping docker build due to minikube docker-env failure or empty output."
                        exit 1 # Keluar dari sh step jika gagal
                    fi
                    echo "--- End Debugging ---"
                """.stripIndent())
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh(script: """
                    echo "Updating deployment.yaml with image tag: ${env.BUILD_ID} for image ${env.APP_NAME}"
                    
                    echo "--- Content of kubernetes/deployment.yaml BEFORE sed ---"
                    cat kubernetes/deployment.yaml
                    echo "--------------------------------------------------------"

                    # Mengganti IMAGE_TAG_PLACEHOLDER dengan nilai ${env.BUILD_ID} Jenkins
                    # Pastikan kubernetes/deployment.yaml menggunakan 'image: ${env.APP_NAME}:IMAGE_TAG_PLACEHOLDER'
                    sed -i "s|IMAGE_TAG_PLACEHOLDER|${env.BUILD_ID}|g" kubernetes/deployment.yaml
                    
                    echo "--- Content of kubernetes/deployment.yaml AFTER sed ---"
                    cat kubernetes/deployment.yaml
                    echo "-------------------------------------------------------"

                    echo "Applying Kubernetes manifests as user ubuntu..."
                    sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/deployment.yaml # Ganti path kubectl jika output 'which kubectl' berbeda
                    SUDO_DEPLOY_EXIT_CODE=\$?
                    if [ "\${SUDO_DEPLOY_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl apply deployment failed with exit code \${SUDO_DEPLOY_EXIT_CODE}"
                        exit 1 # Keluar dari sh step jika gagal
                    fi

                    sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/service.yaml # Ganti path kubectl jika perlu
                    SUDO_SERVICE_EXIT_CODE=\$?
                    if [ "\${SUDO_SERVICE_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl apply service failed with exit code \${SUDO_SERVICE_EXIT_CODE}"
                        exit 1 # Keluar dari sh step jika gagal
                    fi
                """.stripIndent())
            }
        }

        stage('Verify Deployment') {
            steps {
                sh(script: """
                    echo "Verifying deployment rollout status as user ubuntu..."
                    # Ganti 'carvilla-web' jika nama deploymentmu berbeda
                    # Ganti path /usr/bin/kubectl jika perlu
                    sudo -H -u ubuntu /usr/bin/kubectl rollout status deployment/carvilla-web -n default
                    SUDO_ROLLOUT_EXIT_CODE=\$?
                    if [ "\${SUDO_ROLLOUT_EXIT_CODE}" -ne 0 ]; then
                        echo "kubectl rollout status failed with exit code \${SUDO_ROLLOUT_EXIT_CODE}"
                        exit 1 # Keluar dari sh step jika gagal
                    fi
                    
                    echo "Verifikasi deployment selesai."
                    echo "Untuk mengakses aplikasi, jalankan perintah ini di terminal EC2 sebagai user ubuntu:"
                    echo "minikube service <nama-service-carvilla> --url -p minikube" 
                    # Ganti <nama-service-carvilla> dengan nama service dari service.yaml
                """.stripIndent())
            }
        }
    } // Akhir dari blok 'stages'

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
} // Akhir dari blok 'pipeline'
