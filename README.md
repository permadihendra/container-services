# DIY Container Services - Architecture Guide

A comprehensive, production-ready microservices architecture using containerization with Flask applications, PostgreSQL database, Metabase analytics, and NGINX reverse proxy. This project demonstrates a reusable multi-app deployment pattern where you can run multiple Flask instances from a shared template.

---

## Table of Contents

1. [Features](#features)
2. [Architecture Overview](#architecture-overview)
3. [Directory Structure](#directory-structure)
4. [Quick Start](#quick-start)
5. [Service Management](#service-management)
6. [Application Details](#application-details)
7. [Database Configuration](#database-configuration)
8. [API Endpoints](#api-endpoints)
9. [Troubleshooting](#troubleshooting)

---

## Features

### What's Implemented

- **Multi-App Support**: Deploy multiple Flask applications (flask-a, flask-b) from a single template
- **uv Package Manager**: Fast Python package installation using `uv pip install`
- **PostgreSQL Integration**: Shared database instance with isolated databases per app
- **NGINX Reverse Proxy**: Single entry point routing to multiple applications
- **Health Monitoring**: Built-in health check and database test endpoints
- **Container Management**: Shell scripts for easy deployment and testing

### Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Runtime | Python | 3.12-slim |
| Package Manager | uv | Latest |
| Web Server | NGINX | Latest |
| Database | PostgreSQL | 14 |
| Analytics | Metabase | Latest |
| Container | nerdctl/Podman | 2.2.2 |

---

## Architecture Overview

```
                           ┌─────────────────┐
                           │   NGINX (8080)   │
                           │  Reverse Proxy  │
                           └───────┬─────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
    │   Flask-A      │   │   Flask-B      │   │   Metabase     │
    │   (port 5000) │   │   (port 5001)  │   │  (port 3000)   │
    └───────┬───────┘   └───────┬───────┘   └─────────────────┘
           │                   │
           └─────────┬─────────┘
                     ▼
          ┌────────────────────┐
          │   PostgreSQL        │
          │   (port 5432)       │
          ├────────────────────┤
          │ flask_a_db         │ ← flask-a
          │ flask_b_db        │ ← flask-b
          │ metabase_db       │ ← metabase
          └────────────────────┘
```

---

## Directory Structure

```
container-services/
├── compose-service/            # Compose files & infrastructure
│   ├── nginx-compose.yml       # NGINX service
│   ├── nginx.conf            # NGINX routing configuration
│   ├── postgres-compose.yml  # PostgreSQL service
│   ├── metabase-compose.yml  # Metabase analytics
│   └── .env                  # Environment variables
���
├── services/                  # Flask applications
│   ├── common/               # Shared base image
│   │   └── docker-base.Dockerfile
│   │
│   ├── flask-app-template/   # Reusable template ( DON'T modify)
│   │   ├── compose.yml
│   │   ├── Dockerfile
│   │   ├── app/main.py
│   │   ├── requirements.txt
│   │   └── .env.example
│   │
│   ├── flask-a/              # Instance A
│   │   ├── compose.yml
│   │   ├── Dockerfile
│   │   ├── app/main.py
│   │   ├── requirements.txt
│   │   └── .env
│   │
│   └── flask-b/              # Instance B
│       ├── compose.yml
│       ├── Dockerfile
│       ├── app/main.py
│       ├── requirements.txt
│       └── .env
│
├── scripts/                  # Management scripts
│   ├── manage.sh           # Build & deployment
│   └── test.sh            # Testing
│
├── PLANNING.md             # Architecture decisions
├── PROGRESS.md            # Implementation progress
└── README.md              # This file
```

---

## Quick Start

### Prerequisites

```bash
# Required tools
- nerdctl (or docker/podman). [for nerdctl consult here](https://github.com/containerd/nerdctl/tree/main)
- curl (for testing)
- bash (for scripts)
```

### Start All Services

```bash
# Option 1: Using management script
./scripts/manage.sh start-all

# Option 2: Manual startup
cd compose-service
nerdctl compose up -d
```

### Verify Services

```bash
# Using test script
./scripts/test.sh all

# Or manual verification
curl http://localhost:8080/           # flask-a (via NGINX)
curl http://localhost:8080/flask-a/   # flask-a
curl http://localhost:8080/flask-b/    # flask-b
curl http://localhost:3000/          # Metabase
```

---

## Service Management

### Management Script

The `manage.sh` script provides convenient commands for managing services.

```bash
# Build base image with uv
./scripts/manage.sh build-base

# Build specific app
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

# Start specific app
./scripts/manage.sh start flask-a 5000 flask_a_db
./scripts/manage.sh start flask-b 5001 flask_b_db

# Stop specific app
./scripts/manage.sh stop flask-a
./scripts/manage.sh stop flask-b

# Stop all services
./scripts/manage.sh stop-all

# Show status
./scripts/manage.sh status

# View logs
./scripts/manage.sh logs flask-a
./scripts/manage.sh logs flask-b
```

### Test Script

```bash
# Run all tests
./scripts/test.sh all

# Run specific test categories
./scripts/test.sh containers
./scripts/test.sh health
./scripts/test.sh database
./scripts/test.sh nginx
./scripts/test.sh metabase
```

---

## Application Details

### Flask Applications

Each Flask application is isolated with its own:

- **Port**: Unique port (5000, 5001)
- **Database**: Dedicated PostgreSQL database
- **Requirements**: App-specific dependencies
- **Code**: Custom application logic

#### Flask-A

- **Access**: http://localhost:5000 or http://localhost:8080/flask-a/
- **Database**: flask_a_db
- **Dependencies**: flask, psycopg2-binary

#### Flask-B

- **Access**: http://localhost:5001 or http://localhost:8080/flask-b/
- **Database**: flask_b_db
- **Dependencies**: flask, flask-sqlalchemy, sqlalchemy, psycopg2-binary

### PostgreSQL

- **Host**: localhost (container name: compose-service-postgres-1)
- **Port**: 5432
- **User**: user
- **Password**: password
- **Databases**:
  - `flask_a_db` - For flask-a
  - `flask_b_db` - For flask-b
  - `metabase_db` - For Metabase

### NGINX Reverse Proxy

- **Port**: 8080
- **Routing**:
  - `/` → flask-a (default)
  - `/flask-a/` → flask-a
  - `/flask-b/` → flask-b

### Metabase Analytics

- **URL**: http://localhost:3000
- **Database**: metabase_db
- **Default Credentials**: user / password

---

## API Endpoints

### Flask Application Endpoints

| Endpoint | Method | Description | Returns |
|----------|--------|-------------|---------|
| `/` | GET | Home | App name and status |
| `/health` | GET | Health check | JSON with database status |
| `/db-test` | GET | Database test | PostgreSQL version |

### Example Responses

```bash
# Home endpoint
$ curl http://localhost:5000/
flask-a is running.

# Health check
$ curl http://localhost:5000/health
{"database":"connected","status":"healthy"}

# Database test
$ curl http://localhost:5000/db-test
{"status":"ok","version":"PostgreSQL 14.22..."}
```

---

## Configuration

### Environment Variables

Each Flask application uses the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| APP_NAME | flask-a | Application name |
| APP_PORT | 5000 | Internal port |
| DB_HOST | localhost | Database host |
| DB_PORT | 5432 | Database port |
| DB_NAME | flask_a_db | Database name |
| DB_USER | user | Database user |
| DB_PASSWORD | password | Database password |

### Adding New Application

To add a new Flask application (e.g., flask-c):

1. **Copy template**:
   ```bash
   cp -r services/flask-a services/flask-c
   ```

2. **Update configuration**:
   - Edit `services/flask-c/compose.yml` - change port to 5002
   - Edit `services/flask-c/.env` - update APP_NAME and DB_NAME
   - Edit `services/flask-c/app/main.py` - customize application logic

3. **Create database**:
   ```bash
   nerdctl exec compose-service-postgres-1 psql -U user -d mydb -c "CREATE DATABASE flask_c_db;"
   ```

4. **Add NGINX route** in `compose-service/nginx.conf`:
   ```nginx
   location /flask-c/ {
       proxy_pass http://localhost:5002/;
       ...
   }
   ```

5. **Build and start**:
   ```bash
   ./scripts/manage.sh build flask-c
   ./scripts/manage.sh start flask-c 5002 flask_c_db
   ```

---

## Troubleshooting

### Common Issues

#### Container won't start

```bash
# Check logs
nerdctl logs <container-name>

# Check status
nerdctl ps -a
```

#### Database connection failed

```bash
# Verify PostgreSQL is running
nerdctl ps | grep postgres

# Test connection
curl http://localhost:5000/db-test
```

#### NGINX routing not working

```bash
# Restart NGINX
cd compose-service
nerdctl compose restart nginx

# Check NGINX logs
nerdctl logs compose-service-nginx-1
```

### Service Ports

| Service | Port | Container Name |
|---------|-----|----------------|
| Flask-A | 5000 | flask-a |
| Flask-B | 5001 | flask-b |
| NGINX | 8080 | compose-service-nginx-1 |
| PostgreSQL | 5432 | compose-service-postgres-1 |
| Metabase | 3000 | compose-service-metabase-1 |

---

## Scripts Reference

### manage.sh

Comprehensive management script for building, deploying, and managing containers.

#### Usage

```bash
./scripts/manage.sh <command> [options]
```

#### Commands

| Command | Options | Description |
|---------|---------|-------------|
| `build-base` | - | Build base image with uv |
| `build` | `<app-name>` | Build specific app image |
| `start` | `<app> <port> <db>` | Start app with parameters |
| `start-all` | - | Build and start all services |
| `stop` | `<app-name>` | Stop specific app |
| `stop-all` | - | Stop all Flask apps |
| `status` | - | Show all running containers |
| `test` | - | Test all endpoints |
| `logs` | `<app-name>` | Show logs for app |
| `help` | - | Show help |

#### Examples

```bash
# Build base image (one-time setup)
./scripts/manage.sh build-base

# Build a specific app
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

# Start individual apps
./scripts/manage.sh start flask-a 5000 flask_a_db
./scripts/manage.sh start flask-b 5001 flask_b_db

# Stop apps
./scripts/manage.sh stop flask-a
./scripts/manage.sh stop-all

# View status
./scripts/manage.sh status

# View logs
./scripts/manage.sh logs flask-a
./scripts/manage.sh logs flask-b

# Stop all services
./scripts/manage.sh stop-all
```

---

### test.sh

Automated testing script with color-coded output.

#### Usage

```bash
./scripts/test.sh <test-type>
```

#### Test Types

| Test Type | Description |
|-----------|-------------|
| `all` | Run all tests (default) |
| `containers` | Check if all containers are running |
| `health` | Test health check endpoints |
| `database` | Test database connectivity |
| `nginx` | Test NGINX routing |
| `metabase` | Test Metabase accessibility |

#### Examples

```bash
# Run all tests
./scripts/test.sh all

# Run specific test category
./scripts/test.sh containers
./scripts/test.sh health
./scripts/test.sh database

# Combined usage
./scripts/manage.sh build flask-a
./scripts/manage.sh start flask-a 5000 flask_a_db
./scripts/test.sh health
```

#### Sample Output

```
========================================
Running All Tests
========================================
=== Container Tests ===
[PASS] Container running: flask-a
[PASS] Container running: flask-b
[PASS] Container running: compose-service-nginx-1
[PASS] Container running: compose-service-postgres-1
=== Health Check Tests ===
[PASS] Flask-A health: http://localhost:5000/health
[PASS] Flask-B health: http://localhost:5001/health
=== Database Tests ===
[PASS] Flask-A db-test: http://localhost:5000/db-test
[PASS] Flask-B db-test: http://localhost:5001/db-test
=== NGINX Routing Tests ===
[PASS] NGINX root: http://localhost:8080/
[PASS] NGINX /flask-a: http://localhost:8080/flask-a/
[PASS] NGINX /flask-b: http://localhost:8080/flask-b/

========================================
Results: 16 passed, 0 failed
========================================
```

---

### Automation Workflows

#### Development Workflow

```bash
# 1. Start infrastructure
cd compose-service
nerdctl compose up -d

# 2. Make code changes to apps
# Edit files in services/flask-a/app/ or services/flask-b/app/

# 3. Rebuild and restart
./scripts/manage.sh build flask-a
./scripts/manage.sh stop flask-a
./scripts/manage.sh start flask-a 5000 flask_a_db

# 4. Test changes
./scripts/test.sh health
```

#### CI/CD Workflow

```bash
# Build script example
#!/bin/bash
set -e

echo "Building applications..."
./scripts/manage.sh build-base
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

echo "Starting services..."
./scripts/manage.sh start-all

echo "Running tests..."
./scripts/test.sh all

echo "All tests passed!"
```

#### Deployment Workflow

```bash
# 1. Stop existing services
./scripts/manage.sh stop-all

# 2. Build new images
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

# 3. Start all
./scripts/manage.sh start-all

# 4. Verify
./scripts/test.sh all

# 5. Check logs
./scripts/manage.sh logs flask-a
./scripts/manage.sh logs flask-b
```

---

## License

MIT License

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request
