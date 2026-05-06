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

check_requirements() {
    print_header "Checking Requirements"
    
    if command -v nerdctl &> /dev/null; then
        print_success "nerdctl found: $(nerdctl --version)"
    else
        print_error "nerdctl not found"
        exit 1
    fi
    
    if command -v curl &> /dev/null; then
        print_success "curl found"
    else
        print_warning "curl not found, using wget"
    fi
}

build_base_image() {
    print_header "Building Base Image"
    
    nerdctl run -d --name build-base --network host python:3.12-slim sleep infinity
    nerdctl exec build-base pip install uv
    nerdctl commit build-base services/common:docker-base
    nerdctl rm -f build-base
    
    print_success "Base image built: services/common:docker-base"
}

build_app() {
    local APP_NAME=$1
    local APP_DIR="$SERVICES_DIR/$APP_NAME"
    
    if [ ! -d "$APP_DIR" ]; then
        print_error "App directory not found: $APP_NAME"
        exit 1
    fi
    
    print_header "Building $APP_NAME"
    
    nerdctl run -d --name "${APP_NAME}-build" --network host services/common:docker-base sleep infinity
    
    nerdctl exec "${APP_NAME}-build" mkdir -p /app
    nerdctl cp "$APP_DIR/requirements.txt" "${APP_NAME}-build:/app/requirements.txt"
    nerdctl cp "$APP_DIR/app" "${APP_NAME}-build:/app/"
    nerdctl exec -w /app "${APP_NAME}-build" uv pip install --system -r requirements.txt
    
    nerdctl commit "${APP_NAME}-build" "services/${APP_NAME}:app"
    nerdctl rm -f "${APP_NAME}-build"
    
    print_success "$APP_NAME image built: services/${APP_NAME}:app"
}

start_app() {
    local APP_NAME=$1
    local APP_PORT=$2
    local DB_NAME=$3
    
    print_header "Starting $APP_NAME on port $APP_PORT"
    
    nerdctl rm -f "$APP_NAME"
    
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
    
    print_success "$APP_NAME started on port $APP_PORT"
}

start_all() {
    print_header "Starting All Services"
    
    cd "$COMPOSE_DIR" || exit 1
    nerdctl compose up -d
    
    build_base_image
    build_app flask-a
    build_app flask-b
    
    start_app flask-a 5000 flask_a_db
    start_app flask-b 5001 flask_b_db
    
    print_success "All services started"
}

stop_app() {
    local APP_NAME=$1
    
    print_header "Stopping $APP_NAME"
    nerdctl rm -f "$APP_NAME"
    print_success "$APP_NAME stopped"
}

stop_all() {
    print_header "Stopping All Services"
    
    nerdctl rm -f flask-a flask-b
    cd "$COMPOSE_DIR" || exit 1
    nerdctl compose down
    
    print_success "All services stopped"
}

status() {
    print_header "Running Containers"
    nerdctl ps
    
    echo ""
    print_header "Service Endpoints"
    echo "Flask-A:    http://localhost:5000"
    echo "Flask-B:    http://localhost:5001"
    echo "NGINX:      http://localhost:8080"
    echo "Metabase:  http://localhost:3000"
}

test_apps() {
    print_header "Testing Applications"
    
    echo -e "\n${BLUE}Testing Flask-A endpoints:${NC}"
    curl -s http://localhost:5000/ | head -c 100
    echo ""
    curl -s http://localhost:5000/health
    echo ""
    curl -s http://localhost:5000/db-test
    
    echo -e "\n${BLUE}Testing Flask-B endpoints:${NC}"
    curl -s http://localhost:5001/ | head -c 100
    echo ""
    curl -s http://localhost:5001/health
    echo ""
    curl -s http://localhost:5001/db-test
    
    echo -e "\n${BLUE}Testing NGINX routing:${NC}"
    curl -s http://localhost:8080/flask-a/health
    echo ""
    curl -s http://localhost:8080/flask-b/health
}

logs_app() {
    local APP_NAME=$1
    nerdctl logs "$APP_NAME"
}

help() {
    echo "Container Services Management"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  build-base          Build base image with uv"
    echo "  build <app>        Build specific app (flask-a, flask-b)"
    echo "  start <app>        Start specific app"
    echo "  start-all          Start all services"
    echo "  stop <app>        Stop specific app"
    echo "  stop-all          Stop all services"
    echo "  status             Show running containers"
    echo "  test               Test all endpoints"
    echo "  logs <app>         Show logs for app"
    echo "  help               Show this help"
}

case "$1" in
    build-base)
        check_requirements
        build_base_image
        ;;
    build)
        check_requirements
        build_app "$2"
        ;;
    start)
        check_requirements
        start_app "$2" "$3" "$4"
        ;;
    start-all)
        check_requirements
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
        test_apps
        ;;
    logs)
        logs_app "$2"
        ;;
    help|--help|-h)
        help
        ;;
    *)
        help
        ;;
esac