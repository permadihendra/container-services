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

is_container_running() {
    local NAME=$1
    nerdctl ps -a | grep -q "$NAME" && return 0 || return 1
}

is_infrastructure_running() {
    if is_container_running "compose-service-postgres-1" && \
       is_container_running "compose-service-nginx-1"; then
        return 0
    fi
    return 1
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
    if is_container_running "compose-service-postgres-1"; then
        nerdctl exec compose-service-postgres-1 psql -U user -d mydb -c "CREATE DATABASE flask_a_db;" 2>/dev/null || true
        nerdctl exec compose-service-postgres-1 psql -U user -d mydb -c "CREATE DATABASE flask_b_db;" 2>/dev/null || true
        print_success "Databases ready"
    else
        print_warning "PostgreSQL not running, skipping database setup"
    fi
}

compose_up() {
    if is_infrastructure_running; then
        print_warning "Infrastructure already running, skipping..."
        return 0
    fi
    
    print_header "Starting Infrastructure Services"
    cd "$COMPOSE_DIR"
    nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
    ensure_databases
}

build_base_image() {
    if nerdctl images | grep -q "services/common.*docker-base"; then
        print_warning "Base image already exists, skipping build..."
        return 0
    fi
    
    print_header "Building Base Image"
    nerdctl rm -f build-base 2>/dev/null || true
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
    
    if nerdctl images | grep -q "services/${APP_NAME}.*app"; then
        print_warning "Image services/${APP_NAME}:app already exists, skipping build..."
        return 0
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
    
    if is_container_running "$APP_NAME"; then
        print_warning "$APP_NAME already running, restarting..."
        nerdctl rm -f "$APP_NAME"
    fi
    
    print_header "Starting $APP_NAME (port $APP_PORT)"
    
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

get_app_config() {
    local APP_NAME=$1
    case "$APP_NAME" in
        flask-a)
            echo "5000 flask_a_db"
            ;;
        flask-b)
            echo "5001 flask_b_db"
            ;;
        *)
            echo ""
            ;;
    esac
}

start_one() {
    local APP_NAME=$1
    
    if [ -z "$APP_NAME" ]; then
        print_error "Usage: $0 start-one <flask-a|flask-b>"
        return 1
    fi
    
    if [ "$APP_NAME" != "flask-a" ] && [ "$APP_NAME" != "flask-b" ]; then
        print_error "Invalid app: $APP_NAME. Use flask-a or flask-b"
        return 1
    fi
    
    require_nerdctl
    
    print_header "Starting $APP_NAME"
    
    if is_container_running "$APP_NAME"; then
        print_warning "$APP_NAME already running!"
        return 0
    fi
    
    if ! is_infrastructure_running; then
        print_warning "Infrastructure not running, starting..."
        compose_up
    fi
    
    ensure_databases
    
    if ! nerdctl images | grep -q "services/${APP_NAME}.*app"; then
        print_warning "Image not found, building..."
        build_base_image
        build_app "$APP_NAME"
    fi
    
    local CONFIG
    CONFIG=$(get_app_config "$APP_NAME")
    local APP_PORT=$(echo "$CONFIG" | cut -d' ' -f1)
    local DB_NAME=$(echo "$CONFIG" | cut -d' ' -f2)
    
    start_app "$APP_NAME" "$APP_PORT" "$DB_NAME"
    
    print_success "$APP_NAME started on port $APP_PORT"
}

stop_app() {
    local APP_NAME=$1
    if is_container_running "$APP_NAME"; then
        print_header "Stopping $APP_NAME"
        nerdctl rm -f "$APP_NAME" 2>/dev/null || true
        print_success "$APP_NAME stopped"
    else
        print_warning "$APP_NAME not running"
    fi
}

start_all() {
    require_nerdctl
    
    print_header "Starting All Services"
    
    if is_infrastructure_running && is_container_running "flask-a" && is_container_running "flask-b"; then
        print_warning "All services already running!"
        status
        return 0
    fi
    
    compose_up
    ensure_databases
    
    if ! is_container_running "flask-a"; then
        build_base_image
        build_app flask-a
    fi
    
    if ! is_container_running "flask-b"; then
        if ! nerdctl images | grep -q "services/flask-b.*app"; then
            build_base_image
        fi
        build_app flask-b
    fi
    
    start_app flask-a 5000 flask_a_db
    start_app flask-b 5001 flask_b_db
    
    print_success "All services started"
}

stop_all() {
    print_header "Stopping All Services"
    
    if is_container_running "flask-a" || is_container_running "flask-b"; then
        print_header "Stopping Flask Apps"
        nerdctl rm -f flask-a flask-b 2>/dev/null || true
    fi
    
    if is_infrastructure_running; then
        print_header "Stopping Infrastructure"
        cd "$COMPOSE_DIR"
        nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml down 2>/dev/null || true
    else
        print_warning "Infrastructure not running"
    fi
    
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
    echo "  build-base    Build base image with uv (if not exists)"
    echo "  build <app>   Build app image (if not exists)"
    echo "  start <app> <port> <db>  Start app with explicit params"
    echo "  start-one <flask-a|flask-b>  Start single app (auto config)"
    echo "  start-all    Start all services (skip if already running)"
    echo "  stop <app>   Stop app"
    echo "  stop-all    Stop all services"
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
        ;;
    build-base)
        require_nerdctl
        build_base_image
        ;;
    build)
        require_nerdctl
        build_app "$2"
        ;;
    start)
        require_nerdctl
        compose_up
        start_app "$2" "$3" "$4"
        ;;
    start-one)
        start_one "$2"
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