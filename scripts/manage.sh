#!/bin/bash
#
# TaskManager - Container Management Script
# Quick commands to manage the TaskManager Docker containers
#
# Usage: ./scripts/manage.sh [command]
# Commands: start, stop, restart, status, logs, cleanup, monitoring
#

DEPLOY_PATH="/opt/taskmanager"

if [ ! -f "$DEPLOY_PATH/docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found in $DEPLOY_PATH"
    echo "Please ensure the application is properly deployed"
    exit 1
fi

cd "$DEPLOY_PATH"

case "${1:-status}" in
    start)
        echo "▶️  Starting TaskManager services..."
        docker-compose up -d
        sleep 3
        docker-compose ps
        ;;
    stop)
        echo "🛑 Stopping TaskManager services..."
        docker-compose down
        ;;
    restart)
        echo "🔄 Restarting TaskManager services..."
        docker-compose restart
        sleep 3
        docker-compose ps
        ;;
    status)
        echo "📋 TaskManager Service Status"
        echo "=============================="
        docker-compose ps
        echo ""
        echo "Health Checks:"
        echo "=============="
        if docker-compose exec -T backend curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
            echo "✅ Backend: Running"
        else
            echo "❌ Backend: Not responding"
        fi
        
        if docker-compose exec -T mysql mysqladmin ping -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" &> /dev/null; then
            echo "✅ Database: Running"
        else
            echo "❌ Database: Not responding"
        fi
        
        if docker-compose exec -T prometheus wget -q -O /dev/null http://localhost:9090/-/healthy &> /dev/null; then
            echo "✅ Prometheus: Running"
        else
            echo "⚠️  Prometheus: Check needed"
        fi
        
        if docker-compose exec -T grafana wget -q -O /dev/null http://localhost:3000/api/health &> /dev/null; then
            echo "✅ Grafana: Running"
        else
          
    monitoring)
        echo ""
        echo "🔍 MONITORING STACK STATUS"
        echo "=========================="
        echo ""
        echo "Prometheus:  http://$(hostname -I | awk '{print $1}'):9090"
        echo "Grafana:     http://$(hostname -I | awk '{print $1}'):3001"
        echo "Node Export: http://$(hostname -I | awk '{print $1}'):9100"
        echo ""
        echo "Metrics:"
        echo "--------"
        echo "Backend Metrics: http://$(hostname -I | awk '{print $1}'):8080/actuator/prometheus"
        echo ""
        echo "Service Status:"
        echo "---------------"
        docker-compose ps | grep -E "prometheus|grafana|node-exporter"
        echo ""
        echo "📊 View Grafana Dashboard:"
        echo "   1. Open http://$(hostname -I | awk '{print $1}'):3001"
        echo "   2. Login: admin / \$GRAFANA_ADMIN_PASSWORD (from .env)"
        echo "   3. Look for 'TaskManager - System & Application Metrics' dashboard"
        echo ""
        ;;  echo "⚠️  Grafana: Check needed"
        fi
        ;;
    logs)
        service="${2:-all}"
        if [ "$service" = "all" ]; then
        # Backup Prometheus data
        echo "  - Backing up Prometheus data..."
        docker run --rm -v taskmanager_prometheus-data:/data \
            -v "$BACKUP_DIR":/backup \
            busybox tar czf "/backup/prometheus-data-$TIMESTAMP.tar.gz" -C /data . 2>/dev/null || true
        
        # Backup Grafana data
        echo "  - Backing up Grafana data..."
        docker run --rm -v taskmanager_grafana-data:/data \
            -v "$BACKUP_DIR":/backup \
            busybox tar czf "/backup/grafana-data-$TIMESTAMP.tar.gz" -C /data . 2>/dev/null || true
        
        echo "✅ Backup completed: $BACKUP_DIR"
        ls -lh "$BACKUP_DIR"/*.sql "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -10f
        else
            echo "📜 Showing logs from $service service (last 100 lines)..."
            docker-compose logs --tail=100 -f "$service"
        fi
        ;;
    backup)
        echo "💾 Creating backup..."
        BACKUP_DIR="$DEPLOY_PATH/backups"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mkdir -p "$BACKUP_DIR"
        
        # Backup database
        echo "  - Backing up database..."
        docker-compose exec -T mysql mysqldump \
            -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
            "${MYSQL_DATABASE}" > "$BACKUP_DIR/taskmanager_db_$TIMESTAMP.sql"
        
        # Backup configuration
        echo "  - Backing up configuration..."
        cp "$DEPLOY_PATH/.env" "$BACKUP_DIR/.env.$TIMESTAMP"
        
        echo "✅ Backup completed: $BACKUP_DIR"
        ls -lh "$BACKUP_DIR"/*.sql | tail -5
        ;;
    cleanup)
        echo "🧹 Cleaning up unused Docker resources..."
        docker system prune -f --volumes
        echo "✅ Cleanup completed"
        ;;
    shell)
        service="${2:-backend}"
        echo "🔌 Opening shell to $service container..."
        docker-compose exec "$service" /bin/sh || docker-compose exec "$service" /bin/bash
        ;;
    *)
        echo "TaskManager Container Management"
        echo "=================================="
        echo ""
        echo "Usage: ./scripts/manage.sh [command] [options]"
        echo ""
        echo "Commands:"
        echo "  start              - Start all services"
        echo "  stop               - Stop all services"
        echo "  restart            - Restart all services"
        echo "  status             - Show service status and health"
        echo "  logs [service]     - Show logs (service: backend|frontend|mysql|prometheus|grafana|all)"
        echo "  monitoring         - Show monitoring stack status and URLs"
        echo "  backup             - Create database and config backup"
        echo "  cleanup            - Clean up unused Docker resources"
        echo "  shell [service]    - Open shell in container (service: backend|frontend|mysql|prometheus|grafana)"
        echo ""
        echo "Examples:"
        echo "  ./scripts/manage.sh start"
        echo "  ./scripts/manage.sh logs backend"
        echo "  ./scripts/manage.sh monitoring"
        echo "  ./scripts/manage.sh shell prometheus"
        ;;
esac
