# Container Services - README

## Overview
This repository provides a containerized microservices architecture using Docker/Podman with nerdctl for container management. The stack includes Flask application, PostgreSQL with pgvector, Metabase analytics, and NGINX reverse proxy.

## Directory Structure
```
container-services/
├── compose-service/
│   ├── flask-pg-compose.yml
│   ├── metabase-compose.yml
│   ├── nginx-compose.yml
│   ├── nginx.conf
│   └── .env
├── flask-app1/          # Application source (when properly configured)
├── postgres-db/         # Database configuration
├── nginx/              # NGINX config (legacy)
├── PLANNING.md         # Planning documentation
├── PROGRESS.md         # Progress tracking
├── information.md      # Service details & credentials
└── README.md           # This file
```

## Prerequisites
Before you begin, make sure you have the following installed:
- Docker (or Podman)
- nerdctl
- Git
- Basic understanding of Docker compose

## Installation
1. Clone the repository:
```bash
git clone https://github.com/your-username/container-services.git
cd container-services
```

2. Set up environment variables (optional but recommended):
```bash
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password
export METABASE_SITE_URL=http://localhost:3000
```

3. Start the services:
```bash
cd compose-service
nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
```

## Usage
### Accessing Services
| Service     | URL                  | Description |
|-------------|----------------------|-------------|
| Metabase    | http://localhost:3000 | Analytics dashboard |
| Flask App   | http://localhost:8080 | Main application |
| NGINX       | http://localhost:8080 | Reverse proxy |
| PostgreSQL  | (internal)           | Database access |

### Checking Status
```bash
nerdctl compose ps
```

### Viewing Logs
```bash
nerdctl compose logs
```

### Stopping Services
```bash
nerdctl compose down
```

## Service Details
### PostgreSQL (Application)
- **Host**: postgres
- **Port**: 5432
- **Database**: mydb
- **Username**: user
- **Password**: password
- **Connection String**: postgresql://user:password@postgres:5432/mydb

### PostgreSQL (Metabase)
- **Host**: postgres
- **Port**: 5432
- **Database**: metabase_db
- **Username**: user
- **Password**: password
- **Connection String**: postgresql://user:password@postgres:5432/metabase_db

### Metabase
- **URL**: http://localhost:3000
- **Database Connection**: postgres://user:password@postgres:5432/metabase_db

### NGINX
- **Proxy Target**: http://localhost:5000 (Flask app)
- **Access URL**: http://localhost:8080

### Flask Application
- **Port**: 5000
- **Database URL**: postgresql://user:password@postgres:5432/mydb

## Verification
1. Check if all containers are running:
```bash
nerdctl compose ps
```

2. Verify Metabase is accessible:
```bash
curl http://localhost:3000
```

3. Check NGINX proxy:
```bash
curl http://localhost:8080
```

## Notes
- Currently using placeholder images; actual application requires buildkit setup for Flask Dockerfile
- Services use host networking due to iptables limitations in current environment
- Metabase requires separate database from application PostgreSQL

## Contributions
We welcome contributions! Please:
1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a pull request