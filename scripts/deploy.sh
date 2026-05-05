#!/bin/bash
#
# TaskManager - Deployment Script
# This script handles the deployment of the TaskManager application
#
# Usage: ./scripts/deploy.sh [environment]
# Example: ./scripts/deploy.sh production
#

set -e

ENVIRONMENT=${1:-production}
DEPLOY_PATH="/opt/taskmanager"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$DEPLOY_PATH/backups"

echo "🚀 Deploying TaskManager to $ENVIRONMENT..."
echo "========================================="
echo "Timestamp: $TIMESTAMP"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup current configuration
if [ -f "$DEPLOY_PATH/docker-compose.yml" ]; then
    echo "💾 Backing up current configuration..."
    cp "$DEPLOY_PATH/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.$TIMESTAMP"
    cp "$DEPLOY_PATH/.env" "$BACKUP_DIR/.env.$TIMESTAMP" 2>/dev/null || true
fi

# Check if .env file exists
if [ ! -f "$DEPLOY_PATH/.env" ]; then
    echo "❌ Error: .env file not found in $DEPLOY_PATH"
    echo "Please configure .env file before deployment"
    exit 1
fi

# Load environment variables
set -a
source "$DEPLOY_PATH/.env"
set +a

# Validate required environment variables
REQUIRED_VARS=(
    "MYSQL_ROOT_PASSWORD"
    "MYSQL_USER"
    "MYSQL_PASSWORD"
    "JWT_SECRET"
    "CORS_ALLOWED_ORIGINS"
)

echo "🔍 Validating configuration..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required variable $var is not set in .env file"
        exit 1
    fi
done

# Pull latest images
echo "📥 Pulling latest Docker images..."
cd "$DEPLOY_PATH"
docker-compose pull || {
    echo "⚠️  Warning: Some images could not be pulled. Using cached images."
}

# Stop running containers gracefully
echo "🛑 Stopping running services..."
docker-compose down --remove-orphans || true

# Wait for containers to stop
echo "⏳ Waiting for containers to stop..."
sleep 5

# Start new containers
echo "▶️  Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be healthy..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T backend curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo "✅ Backend is healthy"
        break
    fi
    attempt=$((attempt+1))
    echo "⏳ Waiting... (attempt $attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Backend health check failed after $max_attempts attempts"
    echo "📋 Container status:"
    docker-compose ps
    echo "📋 Backend logs:"
    docker-compose logs backend --tail=50
    exit 1
fi

# Verify all services are running
echo "🔍 Verifying all services..."
docker-compose ps

# Run database migrations if needed
echo "🗄️  Checking database health..."
if docker-compose exec -T mysql mysqladmin ping -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" &> /dev/null; then
    echo "✅ Database is healthy"
else
    echo "⚠️  Warning: Database health check returned a warning"
fi

# Verify frontend is serving
echo "🔍 Verifying frontend..."
if curl -s http://localhost:80/index.html > /dev/null 2>&1; then
    echo "✅ Frontend is serving"
else
    echo "⚠️  Warning: Frontend may not be ready yet"
fi

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Service Status:"
docker-compose ps
echo ""
echo "🔗 Access your application:"
echo "   - Frontend: http://$(hostname -I | awk '{print $1}')"
echo "   - Backend API: http://$(hostname -I | awk '{print $1}'):8080"
echo "   - Health: http://$(hostname -I | awk '{print $1}'):8080/actuator/health"
echo ""
echo "📝 Logs:"
echo "   - All services: docker-compose -f $DEPLOY_PATH/docker-compose.yml logs"
echo "   - Backend: docker-compose -f $DEPLOY_PATH/docker-compose.yml logs backend"
echo "   - Frontend: docker-compose -f $DEPLOY_PATH/docker-compose.yml logs frontend"
echo "   - Database: docker-compose -f $DEPLOY_PATH/docker-compose.yml logs mysql"
