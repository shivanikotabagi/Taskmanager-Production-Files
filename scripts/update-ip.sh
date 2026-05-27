#!/bin/bash
#
# TaskManager - EC2 IP Update Script
# Fetches the current public IP from EC2 metadata, updates all config files,
# rebuilds the frontend container (REACT_APP_* vars are baked in at build time),
# and restarts all services.
#
# Usage: ./scripts/update-ip.sh
# Called automatically by the taskmanager systemd service on instance start.
#

set -e

# Resolve deploy path relative to this script's location
DEPLOY_PATH="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
# If script is inside scripts/, go one level up
if [ "$(basename "$DEPLOY_PATH")" = "scripts" ]; then
    DEPLOY_PATH="$(dirname "$DEPLOY_PATH")"
fi

echo "========================================="
echo " TaskManager - IP Update"
echo "========================================="

# --- Fetch current public IP from EC2 metadata ---
echo "Fetching public IP from EC2 metadata service..."

# Try IMDSv2 first (more secure), fall back to IMDSv1
TOKEN=$(curl -s --connect-timeout 3 -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null) || TOKEN=""

if [ -n "$TOKEN" ]; then
    PUBLIC_IP=$(curl -s --connect-timeout 3 \
        -H "X-aws-ec2-metadata-token: $TOKEN" \
        http://169.254.169.254/latest/meta-data/public-ipv4)
else
    PUBLIC_IP=$(curl -s --connect-timeout 3 \
        http://169.254.169.254/latest/meta-data/public-ipv4)
fi

if [ -z "$PUBLIC_IP" ]; then
    echo "ERROR: Could not fetch public IP from EC2 metadata service."
    echo "       Ensure the instance has a public IP and IMDS is reachable."
    exit 1
fi

echo "Public IP: $PUBLIC_IP"

# --- Update frontend/.env (REACT_APP_* vars baked in at build time) ---
FRONTEND_ENV="$DEPLOY_PATH/frontend/.env"
if [ -f "$FRONTEND_ENV" ]; then
    sed -i "s|REACT_APP_API_URL=http://[0-9.]*|REACT_APP_API_URL=http://$PUBLIC_IP|g" "$FRONTEND_ENV"
    sed -i "s|REACT_APP_WS_URL=http://[0-9.]*|REACT_APP_WS_URL=http://$PUBLIC_IP|g" "$FRONTEND_ENV"
    echo "Updated frontend/.env"
else
    echo "WARNING: $FRONTEND_ENV not found, skipping."
fi

# --- Update HOST_IP in .env.taskmanager ---
ENV_FILE="$DEPLOY_PATH/.env.taskmanager"
if [ -f "$ENV_FILE" ]; then
    if grep -q "^HOST_IP=" "$ENV_FILE"; then
        sed -i "s|^HOST_IP=.*|HOST_IP=$PUBLIC_IP|g" "$ENV_FILE"
    else
        echo "HOST_IP=$PUBLIC_IP" >> "$ENV_FILE"
    fi
    echo "Updated .env.taskmanager (HOST_IP=$PUBLIC_IP)"
else
    echo "WARNING: $ENV_FILE not found, skipping."
fi

# --- Export HOST_IP so Docker Compose substitutes it correctly in docker-compose.yml ---
export HOST_IP=$PUBLIC_IP

cd "$DEPLOY_PATH"

# --- Rebuild frontend so new IP is baked into the static bundle ---
echo "Rebuilding frontend container..."
docker compose build --no-cache frontend

# --- Restart all services ---
echo "Starting all services..."
docker compose up -d

echo ""
echo "Done. Application available at:"
echo "  Frontend:  http://$PUBLIC_IP"
echo "  Backend:   http://$PUBLIC_IP:8080"
echo "  Grafana:   http://$PUBLIC_IP:3001"
echo "========================================="
