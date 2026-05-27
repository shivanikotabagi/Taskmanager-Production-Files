pipeline {
    agent { label 'TaskManager-Server' }

    environment {
        APP_NAME    = "taskmanager"
        DEPLOY_PATH = "/home/ubuntu/workspace/taskmanager"
    }

    stages {

        // ─────────────────────────────────────────────────────────────
        // STAGE 1 — Inject the .env file from Jenkins credentials
        // In Jenkins: Manage Jenkins → Credentials → Add
        //   Kind     : Secret file
        //   ID       : taskmanager-env-file     ← must match below
        //   File     : upload your .env.taskmanager
        // ─────────────────────────────────────────────────────────────
        stage('Prepare ENV') {
            steps {
                withCredentials([file(credentialsId: 'taskmanager-env-file', variable: 'ENV_SECRET')]) {
                    sh """
                        mkdir -p ${DEPLOY_PATH}
                        # Copy the secret file from Jenkins into the workspace
                        # with the exact name docker-compose.yml expects
                        cp "\$ENV_SECRET" ${DEPLOY_PATH}/.env.taskmanager
                        chmod 600 ${DEPLOY_PATH}/.env.taskmanager
                        echo "ENV file injected from Jenkins credentials"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 2 — Clone source code
        // ─────────────────────────────────────────────────────────────
        stage('Git Cloning') {
            steps {
                echo "Cloning repository from GitHub..."
                dir("${DEPLOY_PATH}") {
                    git branch: 'main',
                        url: 'https://github.com/shivanikotabagi/Taskmanager-Production-Files.git'
                }
                echo "Repository cloned successfully"
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 3 — Validate every required variable is present
        // ─────────────────────────────────────────────────────────────
        stage('Verify ENV File') {
            steps {
                sh """
                    ENV=${DEPLOY_PATH}/.env.taskmanager

                    if [ ! -f "\$ENV" ]; then
                        echo "ERROR: .env.taskmanager not found at \$ENV"
                        exit 1
                    fi

                    echo ".env.taskmanager found - validating required variables..."

                    REQUIRED_VARS="MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE APP_JWT_SECRET APP_CORS_ALLOWED_ORIGINS HOST_IP GRAFANA_ADMIN_PASSWORD"
                    MISSING=0

                    for VAR in \$REQUIRED_VARS; do
                        VALUE=\$(grep "^\${VAR}=" "\$ENV" | cut -d'=' -f2- | tr -d '[:space:]')
                        if [ -z "\$VALUE" ]; then
                            echo "  MISSING or EMPTY: \$VAR"
                            MISSING=1
                        else
                            echo "  OK: \$VAR"
                        fi
                    done

                    if [ "\$MISSING" = "1" ]; then
                        echo ""
                        echo "ERROR: One or more required variables are missing."
                        echo "Fix your .env.taskmanager in Jenkins credentials and re-run."
                        exit 1
                    fi

                    echo ""
                    echo "All required variables are present."
                """
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 4 — Install Docker / Docker Compose if not present
        // ─────────────────────────────────────────────────────────────
        stage('Setup EC2') {
            steps {
                sh """
                    echo "Checking Docker..."
                    if ! command -v docker &> /dev/null; then
                        echo "Installing Docker..."
                        sudo apt-get update -y
                        sudo apt-get install -y docker.io
                        sudo systemctl start docker
                        sudo systemctl enable docker
                        sudo usermod -aG docker ubuntu
                        echo "Docker installed"
                    else
                        echo "Docker already present"
                    fi

                    if ! docker compose version &> /dev/null; then
                        echo "Installing Docker Compose v2..."
                        sudo apt-get install -y docker-compose-v2
                        echo "Docker Compose installed"
                    else
                        echo "Docker Compose already present"
                    fi
                """
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 5 — Fetch current EC2 public IP and patch the env file
        //           so HOST_IP, CORS, and frontend URLs are always
        //           correct — even after an instance restart/IP change
        // ─────────────────────────────────────────────────────────────
        stage('Update Public IP') {
            steps {
                dir("${DEPLOY_PATH}") {
                    sh """
                        echo "Fetching EC2 public IP from instance metadata..."

                        # Try IMDSv2 first, fall back to IMDSv1
                        TOKEN=\$(curl -s --connect-timeout 3 -X PUT \\
                            "http://169.254.169.254/latest/api/token" \\
                            -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null) || TOKEN=""

                        if [ -n "\$TOKEN" ]; then
                            PUBLIC_IP=\$(curl -s --connect-timeout 3 \\
                                -H "X-aws-ec2-metadata-token: \$TOKEN" \\
                                http://169.254.169.254/latest/meta-data/public-ipv4)
                        else
                            PUBLIC_IP=\$(curl -s --connect-timeout 3 \\
                                http://169.254.169.254/latest/meta-data/public-ipv4)
                        fi

                        if [ -z "\$PUBLIC_IP" ]; then
                            echo "ERROR: Could not fetch EC2 public IP. Is this running on EC2?"
                            exit 1
                        fi

                        echo "Public IP: \$PUBLIC_IP"

                        ENV_FILE="${DEPLOY_PATH}/.env.taskmanager"

                        # Update / insert HOST_IP
                        if grep -q "^HOST_IP=" "\$ENV_FILE"; then
                            sed -i "s|^HOST_IP=.*|HOST_IP=\$PUBLIC_IP|" "\$ENV_FILE"
                        else
                            echo "HOST_IP=\$PUBLIC_IP" >> "\$ENV_FILE"
                        fi

                        # Update APP_CORS_ALLOWED_ORIGINS
                        if grep -q "^APP_CORS_ALLOWED_ORIGINS=" "\$ENV_FILE"; then
                            sed -i "s|^APP_CORS_ALLOWED_ORIGINS=.*|APP_CORS_ALLOWED_ORIGINS=http://\$PUBLIC_IP|" "\$ENV_FILE"
                        else
                            echo "APP_CORS_ALLOWED_ORIGINS=http://\$PUBLIC_IP" >> "\$ENV_FILE"
                        fi

                        # Update frontend .env so REACT_APP_* vars get the new IP at build time
                        FRONTEND_ENV="${DEPLOY_PATH}/frontend/.env"
                        if [ -f "\$FRONTEND_ENV" ]; then
                            sed -i "s|REACT_APP_API_URL=http://[0-9.]*|REACT_APP_API_URL=http://\$PUBLIC_IP|g" "\$FRONTEND_ENV"
                            sed -i "s|REACT_APP_WS_URL=http://[0-9.]*|REACT_APP_WS_URL=http://\$PUBLIC_IP|g" "\$FRONTEND_ENV"
                            echo "frontend/.env updated with new IP"
                        fi

                        echo "IP update complete: \$PUBLIC_IP"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 6 — Build images and start all containers
        // ─────────────────────────────────────────────────────────────
        stage('Build and Deploy') {
            steps {
                dir("${DEPLOY_PATH}") {
                    sh """
                        echo "Stopping old containers..."
                        sudo docker compose --env-file .env.taskmanager down -v || true

                        echo "Building Docker images (no cache)..."
                        sudo docker compose --env-file .env.taskmanager build --no-cache

                        echo "Starting containers..."
                        sudo docker compose --env-file .env.taskmanager up -d

                        echo "Pruning dangling images..."
                        sudo docker image prune -f

                        echo "Running containers:"
                        sudo docker compose --env-file .env.taskmanager ps
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // STAGE 7 — Wait for backend to respond (up to 2.5 min)
        // ─────────────────────────────────────────────────────────────
        stage('Health Check') {
            steps {
                sh """
                    echo "Waiting for backend to be ready..."
                    max_attempts=30
                    attempt=0

                    while [ \$attempt -lt \$max_attempts ]; do
                        STATUS=\$(curl -s -o /dev/null -w "%{http_code}" \\
                            http://localhost:8080/api/auth/login \\
                            -X POST \\
                            -H "Content-Type: application/json" \\
                            -d "{}" 2>/dev/null || echo "000")

                        # 400 = reached backend (bad request = it's alive)
                        # 200 = healthy
                        if [ "\$STATUS" = "400" ] || [ "\$STATUS" = "200" ]; then
                            echo "Backend is healthy - HTTP \$STATUS"
                            break
                        fi

                        attempt=\$((attempt+1))
                        echo "Attempt \$attempt/\$max_attempts - HTTP \$STATUS, retrying in 5s..."
                        sleep 5
                    done

                    if [ \$attempt -eq \$max_attempts ]; then
                        echo "ERROR: Backend health check failed after \$((max_attempts * 5))s"
                        sudo docker compose --env-file ${DEPLOY_PATH}/.env.taskmanager \\
                            -f ${DEPLOY_PATH}/docker-compose.yml logs backend --tail=50
                        exit 1
                    fi

                    echo ""
                    echo "Final container status:"
                    sudo docker compose --env-file ${DEPLOY_PATH}/.env.taskmanager \\
                        -f ${DEPLOY_PATH}/docker-compose.yml ps
                """
            }
        }
    }

    post {
        success {
            script {
                // Read the IP we deployed to so the success message is always accurate
                def ip = sh(
                    script: "grep '^HOST_IP=' ${DEPLOY_PATH}/.env.taskmanager | cut -d'=' -f2 | tr -d '[:space:]'",
                    returnStdout: true
                ).trim()
                echo "========================================="
                echo "Deployment SUCCESSFUL — Build #${BUILD_NUMBER}"
                echo "  Frontend  : http://${ip}"
                echo "  Backend   : http://${ip}:8080"
                echo "  Grafana   : http://${ip}:3001"
                echo "  Prometheus: http://${ip}:9090"
                echo "========================================="
            }
        }
        failure {
            echo "Deployment FAILED at build #${BUILD_NUMBER}. Check stage logs above."
        }
        always {
            // Clean up the injected secret from the workspace so it is
            // never left on disk after the build finishes
            sh "rm -f ${DEPLOY_PATH}/.env.taskmanager || true"
            echo "Pipeline finished."
        }
    }
}