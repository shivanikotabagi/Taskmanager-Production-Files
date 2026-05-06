pipeline {
    agent { label 'TaskManager-Server' }

    parameters {
        string(name: 'DEPLOY_HOST', defaultValue: '', description: 'Target EC2 Public IP or DNS')
        string(name: 'DEPLOY_USER', defaultValue: 'ubuntu', description: 'SSH user on target EC2')
        booleanParam(name: 'SETUP_EC2', defaultValue: false, description: 'Run Docker install on target EC2 (first run only)')
    }

    environment {
        APP_NAME    = "taskmanager"
        DEPLOY_PATH = "/home/ubuntu/taskmanager"
        TARGET_EC2  = "${params.DEPLOY_USER}@${params.DEPLOY_HOST}"
        SSH_CRED_ID = "e6170b39-b87c-4098-aa65-397e25255c77"
    }

    stages {

        stage('Git Cloning') {
            steps {
                echo "Cloning repository from GitHub..."
                git branch: 'main',
                    url: 'https://github.com/shivanikotabagi/Taskmanager-Production-Files.git'
            }
        }

        stage('Setup Target EC2') {
            when {
                expression { return params.SETUP_EC2 == true }
            }
            steps {
                sshagent([env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TARGET_EC2} '
                            echo "Updating apt..."
                            sudo apt-get update -y

                            if ! command -v docker &> /dev/null; then
                                echo "Installing Docker..."
                                sudo apt-get install -y docker.io
                                sudo systemctl start docker
                                sudo systemctl enable docker
                                sudo usermod -aG docker ${params.DEPLOY_USER}
                                echo "Docker installed successfully"
                            else
                                echo "Docker already present, skipping"
                            fi

                            if ! command -v docker-compose &> /dev/null; then
                                echo "Installing Docker Compose..."
                                sudo apt-get install -y docker-compose
                                echo "Docker Compose installed successfully"
                            else
                                echo "Docker Compose already present, skipping"
                            fi

                            mkdir -p ${DEPLOY_PATH}
                            echo "Deploy directory ready: ${DEPLOY_PATH}"
                        '
                    """
                }
            }
        }

        stage('Transfer Code to EC2') {
            steps {
                sshagent([env.SSH_CRED_ID]) {
                    sh """
                        echo "Syncing source code to target EC2..."

                        rsync -avz --delete \\
                            --exclude='.git' \\
                            --exclude='frontend/node_modules' \\
                            --exclude='backend/target' \\
                            -e "ssh -o StrictHostKeyChecking=no" \\
                            ./ ${TARGET_EC2}:${DEPLOY_PATH}/

                        echo "Code transfer complete including .env"
                    """
                }
            }
        }

        stage('Build and Deploy on EC2') {
            steps {
                sshagent([env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TARGET_EC2} \
                            "cd ${DEPLOY_PATH} && \\
                             echo 'Building Docker images on EC2...' && \\
                             docker-compose build --no-cache && \\
                             echo 'Stopping old containers...' && \\
                             docker-compose down && \\
                             echo 'Starting updated containers...' && \\
                             docker-compose up -d && \\
                             echo 'Pruning dangling images...' && \\
                             docker image prune -f && \\
                             echo 'Running containers:' && \\
                             docker-compose ps"
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                sshagent([env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TARGET_EC2} '
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
                                echo "ERROR: Backend health check failed after \$max_attempts attempts"
                                docker-compose -f ${DEPLOY_PATH}/docker-compose.yml logs backend --tail=50
                                exit 1
                            fi

                            echo "Final container status:"
                            docker-compose -f ${DEPLOY_PATH}/docker-compose.yml ps
                        '
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful - Build #${BUILD_NUMBER}"
            echo "Frontend : http://${params.DEPLOY_HOST}"
            echo "Backend  : http://${params.DEPLOY_HOST}:8080"
        }
        failure {
            echo "Deployment failed at build #${BUILD_NUMBER}. Check stage logs above."
        }
        always {
            cleanWs()
        }
    }
}