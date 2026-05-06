pipeline {
    agent { label 'TaskManager-Server' }

    environment {
        APP_NAME    = "taskmanager"
        DEPLOY_PATH = "/home/ubuntu/workspace/taskmanager"
        ENV_FILE    = "/home/ubuntu/.env.taskmanager"
    }

    stages {

        stage('Git Cloning') {
            steps {
                echo "Cloning repository from GitHub..."
                sh "mkdir -p ${DEPLOY_PATH}"
                dir("${DEPLOY_PATH}") {
                    git branch: 'main',
                        url: 'https://github.com/shivanikotabagi/Taskmanager-Production-Files.git'
                }
                sh "cp ${ENV_FILE} ${DEPLOY_PATH}/.env.taskmanager"
                echo ".env.taskmanager copied successfully"
            }
        }

        stage('Verify ENV File') {
            steps {
                sh """
                    if [ ! -f ${DEPLOY_PATH}/.env.taskmanager ]; then
                        echo "ERROR: .env.taskmanager file missing at ${DEPLOY_PATH}/.env.taskmanager"
                        echo "Please create it at /home/ubuntu/.env.taskmanager on the server"
                        exit 1
                    else
                        echo ".env.taskmanager file found"
                    fi
                """
            }
        }

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
                        echo "Installing Docker Compose..."
                        sudo apt-get install -y docker-compose-v2
                        echo "Docker Compose installed"
                    else
                        echo "Docker Compose already present"
                    fi
                """
            }
        }

        stage('Build and Deploy') {
            steps {
                dir("${DEPLOY_PATH}") {
                    sh """
                        echo "Stopping old containers and removing volumes..."
                        sudo docker compose down -v || true

                        echo "Building Docker images..."
                        sudo docker compose build --no-cache

                        echo "Starting containers..."
                        sudo docker compose up -d

                        echo "Pruning dangling images..."
                        sudo docker image prune -f

                        echo "Running containers:"
                        sudo docker compose ps
                    """
                }
            }
        }

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

                        if [ "\$STATUS" = "400" ] || [ "\$STATUS" = "200" ]; then
                            echo "Backend is healthy - HTTP status: \$STATUS"
                            break
                        fi

                        attempt=\$((attempt+1))
                        echo "Attempt \$attempt/\$max_attempts - HTTP \$STATUS, retrying in 5s..."
                        sleep 5
                    done

                    if [ \$attempt -eq \$max_attempts ]; then
                        echo "ERROR: Backend health check failed"
                        sudo docker compose -f ${DEPLOY_PATH}/docker-compose.yml logs backend --tail=50
                        exit 1
                    fi

                    echo "Final container status:"
                    sudo docker compose -f ${DEPLOY_PATH}/docker-compose.yml ps
                """
            }
        }
    }

    post {
        success {
            echo "Deployment successful - Build #${BUILD_NUMBER}"
            echo "Frontend : http://34.226.199.223"
            echo "Backend  : http://34.226.199.223:8080"
        }
        failure {
            echo "Deployment failed at build #${BUILD_NUMBER}. Check stage logs above."
        }
        always {
            echo "Pipeline finished."
        }
    }
}