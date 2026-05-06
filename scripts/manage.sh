#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_DIR/services"
COMPOSE_DIR="$PROJECT_DIR/compose-service"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

require_nerdctl() {
    if ! command -v nerdctl &> /dev/null; then
        print_error "nerdctl not found"
        exit 1
    fi
    print_success "nerdctl: $(nerdctl --version)"
}

compose_down() {
    print_header "Stopping All Services"
    
    print_header "Stopping Flask Apps"
    nerdctl rm -f flask-a flask-b 2>/dev/null || true
    
    print_header "Stopping Infrastructure Services"
    cd "$COMPOSE_DIR"
    nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml down 2>/dev/null || true
    print_success "All services stopped"
}

ensure_databases() {
    print_header "Ensuring Databases"
    if nerdctl ps | grep -q compose-service-postgres-1; then
        nerdctl exec compose-service-postgres-1 psql -U user -d mydb -c "CREATE DATABASE flask_a_db;" 2>/dev/null || true
        nerdctl exec compose-service-postgres-1 psql -U user -d mydb -c "CREATE DATABASE flask_b_db;" 2>/dev/null || true
        print_success "Databases ready"
    fi
}

compose_up() {
    print_header "Starting Infrastructure Services"
    cd "$COMPOSE_DIR"
    nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
    ensure_databases
}

build_base_image() {
    print_header "Building Base Image"
    
    nerdctl run -d --name build-base --network host python:3.12-slim sleep infinity
    nerdctl exec build-base pip install uv
    nerdctl commit build-base services/common:docker-base
    nerdctl rm -f build-base
    
    print_success "Base image: services/common:docker-base"
}

build_app() {
    local APP_NAME=$1
    local APP_DIR="$SERVICES_DIR/$APP_NAME"
    
    if [ ! -d "$APP_DIR" ]; then
        print_error "App not found: $APP_NAME"
        exit 1
    fi
    
    print_header "Building $APP_NAME"
    
    nerdctl rm -f "${APP_NAME}-build" 2>/dev/null || true
    nerdctl run -d --name "${APP_NAME}-build" --network host services/common:docker-base sleep infinity
    
    nerdctl exec "${APP_NAME}-build" mkdir -p /app
    nerdctl cp "$APP_DIR/requirements.txt" "${APP_NAME}-build:/app/requirements.txt"
    nerdctl cp "$APP_DIR/app" "${APP_NAME}-build:/app/"
    nerdctl exec -w /app "${APP_NAME}-build" uv pip install --system -r requirements.txt
    
    nerdctl commit "${APP_NAME}-build" "services/${APP_NAME}:app"
    nerdctl rm -f "${APP_NAME}-build"
    
    print_success "Image: services/${APP_NAME}:app"
}

start_app() {
    local APP_NAME=$1
    local APP_PORT=$2
    local DB_NAME=$3
    
    print_header "Starting $APP_NAME (port $APP_PORT)"
    
    nerdctl rm -f "$APP_NAME" 2>/dev/null || true
    
    nerdctl run -d --name "$APP_NAME" \
        --network host \
        -e APP_NAME="$APP_NAME" \
        -e APP_PORT="$APP_PORT" \
        -e DB_HOST=localhost \
        -e DB_PORT=5432 \
        -e DB_NAME="$DB_NAME" \
        -e DB_USER=user \
        -e DB_PASSWORD=password \
        "services/${APP_NAME}:app" \
        python /app/app/main.py
    
    print_success "$APP_NAME started"
}

stop_app() {
    local APP_NAME=$1
    print_header "Stopping $APP_NAME"
    nerdctl rm -f "$APP_NAME" 2>/dev/null || true
    print_success "$APP_NAME stopped"
}

compose_up() {
    print_header "Starting Infrastructure Services"
    cd "$COMPOSE_DIR"
    nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
    print_success "Infrastructure started"
}

start_all() {
    require_nerdctl
    
    print_header "Starting All Services"
    
    compose_up
    ensure_databases
    
    build_base_image
    build_app flask-a
    build_app flask-b
    
    start_app flask-a 5000 flask_a_db
    start_app flask-b 5001 flask_b_db
    
    print_success "All services started"
}

stop_all() {
    print_header "Stopping All Services"
    
    print_header "Stopping Flask Apps"
    nerdctl rm -f flask-a flask-b 2>/dev/null || true
    
    print_header "Stopping Infrastructure"
    cd "$COMPOSE_DIR"
    nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml down 2>/dev/null || true
    
    print_success "All services stopped"
}

status() {
    print_header "Running Containers"
    nerdctl ps
    
    echo ""
    print_header "Endpoints"
    echo "Flask-A:  http://localhost:5000"
    echo "Flask-B:  http://localhost:5001"
    echo "NGINX:   http://localhost:8080"
    echo "Metabase: http://localhost:3000"
}

test_all() {
    "$SCRIPT_DIR/test.sh" all
}

logs() {
    local APP_NAME=${1:-}
    if [ -n "$APP_NAME" ]; then
        nerdctl logs "$APP_NAME"
    else
        print_header "All Logs"
        nerdctl logs compose-service-nginx-1 2>/dev/null || true
        nerdctl logs flask-a 2>/dev/null || true
        nerdctl logs flask-b 2>/dev/null || true
    fi
}

help() {
    echo "Container Services Management"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  compose-down     Stop infrastructure (nginx, postgres, metabase)"
    echo "  compose-up     Start infrastructure"
    echo "  build-base    Build base image with uv"
    echo "  build <app>   Build app image (flask-a, flask-b)"
    echo "  start <app> <port> <db>  Start app"
    echo "  start-all    Build and start all services"
    echo "  stop <app>   Stop app"
    echo "  stop-all    Stop all Flask apps"
    echo "  status      Show running containers"
    echo "  test        Run all tests"
    echo "  logs [app]  Show logs"
    echo "  help        Show this help"
}

case "$1" in
    compose-down)
        require_nerdctl
        compose_down
        ;;
    compose-up)
        require_nerdctl
        compose_up
        ensure_databases
        ;;
    build-base)
        require_nerdctl
        compose_up
        ensure_databases
        build_base_image
        ;;
    build)
        require_nerdctl
        compose_up
        ensure_databases
        build_app "$2"
        ;;
    start)
        require_nerdctl
        compose_up
        ensure_databases
        start_app "$2" "$3" "$4"
        ;;
    start-all)
        start_all
        ;;
    stop)
        stop_app "$2"
        ;;
    stop-all)
        stop_all
        ;;
    status)
        status
        ;;
    test)
        test_all
        ;;
    logs)
        logs "$2"
        ;;
    help|--help|-h)
        help
        ;;
    *)
        help
        ;;
esac