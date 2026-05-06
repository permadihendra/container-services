# Container Services - Information Guide

## Overview
This repository provides a containerized microservices architecture using Docker/Podman with nerdctl for container management. The stack includes Flask application, PostgreSQL with pgAdmin, Metabase analytics, and NGINX reverse proxy.

## Architecture Concept

### Service Organization
- **Compose-based Management**: All services are defined in compose files within `compose-service/` directory
- **Network Mode**: Uses host networking for simplicity in restricted environments
- **Single PostgreSQL**: Shared database for all apps with isolated databases

## Services

### 1. PostgreSQL with pgAdmin (`postgres-compose.yml`)
- **Purpose**: Database with web admin interface
- **Images**:
  - postgres:14 (database)
  - dpage/pgadmin4 (web admin)
- **Ports**:
  - PostgreSQL: 5432 (internal)
  - pgAdmin: 5050 (external)
- **Key Configuration**:
  - POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
  - PGADMIN_DEFAULT_EMAIL, PGADMIN_DEFAULT_PASSWORD
  - PGADMIN_LISTEN_PORT: 5050 (required for non-root access)

### pgAdmin Configuration Details
- **URL**: http://localhost:5050
- **Email**: admin@example.com
- **Password**: password
- **Database Connection**:
  - Host: localhost
  - Port: 5432
  - Username: user
  - Password: password
  - Database: mydb

### Adding a New Server in pgAdmin
1. Login to pgAdmin at http://localhost:5050
2. Click "Add New Server"
3. Fill in registration form:
   - **Name**: PostgreSQL (any label)
   - **Host**: localhost
   - **Port**: 5432
   - **Database**: mydb
   - **Username**: user
   - **Password**: password
4. Click "Save"

### 2. Metabase (`metabase-compose.yml`)
- **Purpose**: Business intelligence and analytics dashboard
- **Image**: metabase/metabase:latest
- **Dependencies**: Separate PostgreSQL instance
- **Port**: 3000
- **Key Configuration**:
  - `MB_DB_CONNECTION_URI`: Full connection string to Metabase database
  - `METABASE_SITE_URL`: Base URL for the application
  - Requires `extra_hosts` for hostname resolution

### 3. NGINX (`nginx-compose.yml`)
- **Purpose**: Reverse proxy and entry point
- **Image**: nginx:latest
- **Port**: 8080 (external, port 80 requires root)
- **Configuration**: Proxies requests to Flask application

### 4. PostgreSQL with pgAdmin
- **Purpose**: Database with web admin interface
- **Images**: postgres:14, dpage/pgadmin4
- **Ports**: 
  - PostgreSQL: 5432
  - pgAdmin: 5050
- **Credentials**:
  - PostgreSQL: user / password
  - pgAdmin: admin@example.com / password
- **pgAdmin URL**: http://localhost:5050

## Key Items for Running

### Critical Configuration
1. **Hostname Mapping**: Required for Metabase
   ```yaml
   extra_hosts:
     - "metabase:127.0.0.1"
     - "postgres:host-gateway"
   hostname: localhost
   ```

2. **Database Setup**: Each Flask app gets its own database (auto-created)

3. **Port Accessibility**:
   - NGINX: 8080
   - Metabase: 3000
   - PostgreSQL: 5432
   - pgAdmin: 5050

4. **Network Mode**: Uses `network_mode: "host"` to avoid iptables dependency

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Metabase fails with "Cannot run without instance id" | Add hostname mapping with `extra_hosts` |
| NGINX fails with "Permission denied" on port 80 | Change to port 8080 |
| Volume syntax error | Remove top-level volumes section, use inline volumes |
| Container networking fails | Use host network mode instead of bridge |

### Environment Variables

**Metabase**:
- `METABASE_SITE_URL`: http://localhost:3000
- `MB_DB_CONNECTION_URI`: postgres://user:password@postgres:5432/metabase_db

**PostgreSQL**:
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

## Running the Services

### Start Services
```bash
cd compose-service
nerdctl compose -f flask-pg-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
```

### Check Status
```bash
nerdctl compose ps
```

### View Logs
```bash
nerdctl compose logs
```

### Stop Services
```bash
nerdctl compose down
```

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
└── information.md      # This file
```

## Service Credentials & Connection Details

### PostgreSQL (Application Database)
| Property | Value |
|----------|-------|
| Host | localhost |
| Port | 5432 |
| Database | mydb |
| Username | user |
| Password | password |
| Connection String | `postgres://user:password@localhost:5432/mydb` |

### PostgreSQL (Metabase Database)
| Property | Value |
|----------|-------|
| Host | localhost |
| Port | 5432 |
| Database | metabase_db |
| Username | user |
| Password | password |
| Connection String | `postgres://user:password@localhost:5432/metabase_db` |

### Metabase
| Property | Value |
|----------|-------|
| URL | http://localhost:3000 |
| Database Host | postgres (via extra_hosts) |
| Database Port | 5432 |
| Database Name | metabase_db |
| Database User | user |
| Database Password | password |

### NGINX
| Property | Value |
|----------|-------|
| URL | http://localhost:8080 |
| Proxies to | localhost:5000 (Flask) |

### pgAdmin
| Property | Value |
|----------|-------|
| URL | http://localhost:5050 |
| Email | admin@example.com |
| Password | password |
| Connects to | localhost:5432 | |

### Flask Application
| Property | Value |
|----------|-------|
| Port | 5000 (internal) |
| Database URL | `postgres://user:password@localhost:5432/mydb` |

## Notes
- Currently using placeholder images; actual application requires buildkit setup for Flask Dockerfile
- Services use host networking due to iptables limitations in current environment
- Metabase requires separate database from application PostgreSQL