#!/bin/bash
#
# TaskManager - EC2 Deployment Setup Script
# This script initializes the EC2 instance for running the TaskManager application
#
# Usage: ./scripts/setup-ec2.sh
#

set -e

echo "🚀 Setting up TaskManager EC2 instance..."
echo "========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose
echo "📦 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Create deployment directory
echo "📁 Creating deployment directory..."
DEPLOY_PATH="/opt/taskmanager"
mkdir -p "$DEPLOY_PATH"
cd "$DEPLOY_PATH"

# Create .env file from template if it doesn't exist
if [ ! -f "$DEPLOY_PATH/.env" ]; then
    echo "⚠️  .env file not found. Creating from template..."
    if [ -f "$DEPLOY_PATH/.env.example" ]; then
        cp "$DEPLOY_PATH/.env.example" "$DEPLOY_PATH/.env"
        echo "📝 Please update $DEPLOY_PATH/.env with your configuration"
    else
        echo "❌ .env.example not found. Please copy it to $DEPLOY_PATH/"
        exit 1
    fi
fi

# Create docker network
echo "🔗 Creating Docker network..."
docker network create taskmanager-network 2>/dev/null || echo "Network already exists"

# Create necessary directories
echo "📁 Creating data directories..."
mkdir -p "$DEPLOY_PATH/mysql-data"
mkdir -p "$DEPLOY_PATH/logs"
mkdir -p "$DEPLOY_PATH/backups"

# Set proper permissions
echo "🔐 Setting permissions..."
chmod 750 "$DEPLOY_PATH"
chmod 700 "$DEPLOY_PATH/mysql-data"
chmod 700 "$DEPLOY_PATH/.env"

# Create a systemd service to auto-start the containers
echo "🔧 Creating systemd service..."
cat > /etc/systemd/system/taskmanager.service << 'EOF'
[Unit]
Description=TaskManager Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/taskmanager
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.yml down
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable taskmanager.service

echo ""
echo "✅ EC2 setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Update /opt/taskmanager/.env with your configuration"
echo "2. Copy docker-compose.yml to /opt/taskmanager/"
echo "3. Run: systemctl start taskmanager"
echo "4. Check status: docker-compose -f /opt/taskmanager/docker-compose.yml ps"
echo ""
echo "🔗 Services will be available at:"
echo "   - Frontend: http://your-ec2-ip"
echo "   - Backend API: http://your-ec2-ip:8080"
echo "   - Health Check: http://your-ec2-ip:8080/actuator/health"
