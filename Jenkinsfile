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
                    sh(script: """ // Menggunakan triple double quotes untuk multiline string Groovy
                        echo "Updating deployment.yaml with image tag: ${env.BUILD_ID} for image ${env.APP_NAME}"

                        echo "--- Content of kubernetes/deployment.yaml BEFORE sed ---"
                        cat kubernetes/deployment.yaml
                        echo "--------------------------------------------------------"

                        # Variabel Jenkins/Groovy akan diekspansi di sini
                        # Pola untuk sed: cari '\${BUILD_ID}' ganti dengan 'nilai_build_id_jenkins'
                        # Kita perlu escape $ dan { } untuk sed jika ingin literal, tapi kita ingin literal \${BUILD_ID}
                        # \\\ -> \ (untuk shell)
                        # \\$ -> \$ (untuk sed agar $ literal)
                        # Jadi, untuk mencari \${BUILD_ID} literal: \\\\\\\\\\${BUILD_ID} akan terlalu rumit.

                        # Cara yang lebih sederhana:
                        # Pastikan deployment.yaml punya placeholder unik, misal: IMAGE_TAG_PLACEHOLDER
                        # Lalu: sed -i "s|IMAGE_TAG_PLACEHOLDER|${env.BUILD_ID}|g" kubernetes/deployment.yaml
                        # Ini jauh lebih aman dan mudah.

                        # NAMUN, jika kita HARUS tetap dengan \${BUILD_ID} di YAML:
                        # Pola pencarian untuk sed adalah string literal: \${BUILD_ID}
                        # Pola pengganti adalah nilai dari env.BUILD_ID
                        
                        # Mari kita coba escape \ dan $ dengan hati-hati untuk sed di dalam shell
                        # String yang ingin kita cari di file: image: carvilla:\${BUILD_ID}
                        # String pengganti: image: carvilla:20 (misalnya)
                        
                        # Perintah sed:
                        # sed 's/SEARCH_PATTERN/REPLACE_PATTERN/' file
                        # SEARCH_PATTERN: image: carvilla:\\\${BUILD_ID} (agar sed melihat literal \${BUILD_ID})
                        #   - \ akan menjadi literal \ untuk sed
                        #   - \$ akan menjadi literal $ untuk sed
                        # REPLACE_PATTERN: image: carvilla:${env.BUILD_ID}
                        
                        # Menggunakan single quote untuk sed agar shell tidak banyak interpretasi,
                        # lalu menyuntikkan variabel Jenkins dengan string concatenation.
                        
                        SEARCH_FOR='image: '${env.APP_NAME}':\\${BUILD_ID}' # String Groovy, akan menjadi 'image: carvilla:\\${BUILD_ID}'
                        REPLACE_WITH='image: '${env.APP_NAME}':'${env.BUILD_ID} # String Groovy, akan menjadi 'image: carvilla:20'
                        
                        echo "SED Search: ${SEARCH_FOR}"
                        echo "SED Replace: ${REPLACE_WITH}"
                        
                        # Menggunakan / sebagai delimiter agar tidak bentrok jika path mengandung /
                        # sed -i 's|'"{SEARCH_FOR}"'|'"{REPLACE_WITH}"'|g' kubernetes/deployment.yaml
                        # Baris di atas mungkin salah karena interpolasi di dalam single quote.

                        # Cara yang lebih aman untuk string kompleks di sed dari variabel shell:
                        # Export variabel lalu gunakan di sed. Tapi di Jenkinsfile sh, ini satu blok.

                        # Paling sederhana dan mungkin berhasil jika yaml punya \${BUILD_ID}:
                        # Kita ingin sed mencari literal '\${BUILD_ID}' dan menggantinya dengan nilai dari ${env.BUILD_ID} (misal 20)
                        # Di dalam double quotes untuk sh, $ perlu di-escape agar tidak diekspansi shell, tapi kita ingin ${env.BUILD_ID} diekspansi Groovy.
                        
                        # Mari kita gunakan pendekatan yang lebih sederhana:
                        # Jika `deployment.yaml` punya `image: carvilla:IMAGE_TAG_PLACEHOLDER`
                        # Maka `sed -i "s|IMAGE_TAG_PLACEHOLDER|${env.BUILD_ID}|g" kubernetes/deployment.yaml` akan mudah.

                        # Karena kita terjebak dengan \${BUILD_ID} di YAML, coba ini:
                        # Ini akan mengganti SEMUA kemunculan '\${BUILD_ID}' dengan nilai ${env.BUILD_ID}
                        # Ini kurang aman jika '\${BUILD_ID}' muncul di tempat lain, tapi untuk file kecil ini mungkin OK.
                        echo "Trying a simpler sed to replace literal \\\${BUILD_ID} with ${env.BUILD_ID}"
                        sed -i 's|\\\${BUILD_ID}|'${env.BUILD_ID}'|g' kubernetes/deployment.yaml
                        
                        echo "--- Content of kubernetes/deployment.yaml AFTER sed ---"
                        cat kubernetes/deployment.yaml
                        echo "-------------------------------------------------------"

                        echo "Applying Kubernetes manifests as user ubuntu..."
                        sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/deployment.yaml
                        SUDO_DEPLOY_EXIT_CODE=\$?
                        if [ "\${SUDO_DEPLOY_EXIT_CODE}" -ne 0 ]; then
                            echo "kubectl apply deployment failed with exit code \${SUDO_DEPLOY_EXIT_CODE}"
                            exit 1
                        fi

                        sudo -H -u ubuntu /usr/bin/kubectl apply -f kubernetes/service.yaml
                        SUDO_SERVICE_EXIT_CODE=\$?
                        if [ "\${SUDO_SERVICE_EXIT_CODE}" -ne 0 ]; then
                            echo "kubectl apply service failed with exit code \${SUDO_SERVICE_EXIT_CODE}"
                            exit 1
                        fi
                    """.stripIndent()) // stripIndent penting
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
