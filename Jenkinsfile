pipeline {
    agent any

    environment {
        // Application Configuration
        APP_NAME = "taskmanager"
        DOCKER_NETWORK = "taskmanager-network"
        
        // Deployment Configuration
        DEPLOY_USER = "${DEPLOY_USER}"
        DEPLOY_HOST = "${DEPLOY_HOST}"
        DEPLOY_PATH = "/opt/taskmanager"
        
        // Build Variables
        BUILD_ID = "${BUILD_NUMBER}"
        TIMESTAMP = sh(script: "date +%Y%m%d_%H%M%S", returnStdout: true).trim()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code..."
                    checkout scm
                }
            }
        }

        stage('Build Backend') {
            steps {
                script {
                    echo "🔨 Building backend with Maven..."
                    dir('backend') {
                        sh 'mvn clean package -DskipTests -q'
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    echo "🐳 Building Docker images locally..."
                    sh '''
                        # Build Backend
                        docker build -t taskmanager-backend:latest ./backend

                        # Build Frontend
                        docker build -t taskmanager-frontend:latest ./frontend

                        # Verify images were built
                        docker images | grep taskmanager
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    echo "🚀 Deploying to EC2 instance..."
                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            # Copy deployment files to EC2
                            scp -i ${SSH_KEY} -o StrictHostKeyChecking=no \
                                docker-compose.yml \
                                .env.example \
                                ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/
                            
                            # Execute deployment script on EC2
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} << 'DEPLOY_SCRIPT'
                                cd ${DEPLOY_PATH}

                                # Create docker network if it doesn't exist
                                docker network create ${DOCKER_NETWORK} 2>/dev/null || true

                                # Build Docker images locally on EC2
                                echo "🐳 Building Docker images on EC2..."
                                docker build -t taskmanager-backend:latest ./backend
                                docker build -t taskmanager-frontend:latest ./frontend

                                # Stop and remove old containers
                                docker-compose down

                                # Start new containers
                                docker-compose up -d

                                # Wait for services to be healthy
                                sleep 10

                                # Check services
                                docker-compose ps

                                echo "✅ Deployment completed successfully!"
                            DEPLOY_SCRIPT
                        '''
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "🏥 Performing health checks..."
                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} << 'HEALTH_CHECK'
                                # Wait for backend to be ready
                                max_attempts=30
                                attempt=0
                                while [ $attempt -lt $max_attempts ]; do
                                    if curl -f http://localhost:8080/actuator/health > /dev/null 2>&1; then
                                        echo "✅ Backend is healthy"
                                        break
                                    fi
                                    attempt=$((attempt+1))
                                    sleep 2
                                done
                                
                                if [ $attempt -eq $max_attempts ]; then
                                    echo "❌ Backend health check failed"
                                    exit 1
                                fi
                            HEALTH_CHECK
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully!"
            // Add notification here (email, Slack, etc.)
        }
        failure {
            echo "❌ Pipeline failed. Check logs above for details."
            // Add notification here
        }
        always {
            cleanWs()
        }
    }
}
