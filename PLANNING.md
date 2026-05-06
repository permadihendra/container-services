# PLANNING.md - Refactoring Plan for Reusable Services

## Goal: Reusable App Service Structure

Enable deploying multiple instances (e.g., flask-a, flask-b) from a single template with different requirements.txt.

---

## Architecture

### Directory Structure

```
services/
├── common/                          # Shared base configurations
│   └── docker-base.Dockerfile       # Base image with uv installed
│
├── flask-app-template/              # REUSABLE template (DON'T modify per app)
│   ├── compose.yml
│   ├── Dockerfile                  # Builds FROM common/docker-base
│   ├── app/
│   │   └── main.py
│   ├── requirements.txt            # Placeholder - override in each instance
│   └── .env.example
│
├── flask-a/                         # Instance A
│   ├── compose.yml
│   ├── requirements.txt            # App-specific dependencies
│   └── app/
│       └── main.py                # Optional: override if logic differs
│
├── flask-b/                         # Instance B
│   ├── compose.yml
│   ├── requirements.txt           # App-specific dependencies
│   └── app/
│       └── main.py
```

---

## Package Manager: uv

### uv Commands Reference

| pip (old) | uv (new) |
|----------|---------|
| `pip install -r requirements.txt` | `uv pip install -r requirements.txt` |
| `pip install package` | `uv pip install package` |
| `pip install --no-cache-dir -r requirements.txt` | `uv pip install -r requirements.txt` |

### Dockerfile Pattern

```dockerfile
# Base image with uv installed
FROM python:3.12-slim
RUN pip install uv

# Install dependencies using uv
COPY requirements.txt .
RUN uv pip install -r requirements.txt

# Run the app
CMD ["uv", "run", "python", "main.py"]
```

---

## Deployment Commands

### Deploy Specific App Instance

```bash
# Deploy only Flask A
cd services/flask-a && nerdctl compose up -d

# Deploy only Flask B
cd services/flask-b && nerdctl compose up -d

# Check status
nerdctl compose ps

# View logs
nerdctl compose logs

# Stop services
nerdctl compose down
```

---

## Benefits

1. **Layer Caching** - Same base image, only rebuild requirements layer when requirements.txt changes
2. **Instance Isolation** - Each app (flask-a, flask-b) is independent
3. **Template Reusability** - Base template remains unchanged
4. **uv Speed** - Faster package installation than pip

---

## Implementation Checklist

- [x] Create common/docker-base.Dockerfile with uv
- [x] Create flask-app-template/ structure
- [x] Create flask-a/ instance
- [x] Create flask-b/ instance
- [x] Test deployment for each instance

---

## NGINX Reverse Proxy

### Purpose
Single NGINX instance routes to multiple Flask apps.

### Configuration Location
`compose-service/nginx.conf`

### Routing Pattern
```nginx
location /flask-a/ {
    proxy_pass http://localhost:5000/;
    ...
}

location /flask-b/ {
    proxy_pass http://localhost:5001/;
    ...
}
```

### Access URLs
- Default: `http://localhost:8080/` → flask-a
- `http://localhost:8080/flask-a/` → flask-a
- `http://localhost:8080/flask-b/` → flask-b
- pgAdmin: `http://localhost:5050` (direct access only)

### Add New App Routing
To add flask-c on port 5002:
1. Update app's port in compose.yml
2. Add location block to nginx.conf:
```nginx
location /flask-c/ {
    proxy_pass http://localhost:5002/;
    ...
}
```

---

## PostgreSQL Integration

### Database Setup (Existing PostgreSQL)
Single PostgreSQL instance serves multiple apps with separate databases.

### Databases Created
| Database | For App | Port |
|----------|--------|------|
| flask_a_db | flask-a | 5000 |
| flask_b_db | flask-b | 5001 |
| metabase_db | metabase | 3000 |

### Environment Variables
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flask_a_db      # or flask_b_db
DB_USER=user
DB_PASSWORD=password
```

### App Configuration (main.py pattern)
```python
import psycopg2
import os

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "database": os.getenv("DB_NAME", "flask_a_db"),
    "user": os.getenv("DB_USER", "user"),
    "password": os.getenv("DB_PASSWORD", "password"),
}
```

### Test Endpoints
- `/health` - Check app and database health
- `/db-test` - Test database connection

---

## Complete Architecture

```
compose-service/
├── nginx/                  # Reverse proxy
├── postgres-compose.yml    # PostgreSQL + pgAdmin
│   ├── postgres:14       # Database
│   └── pgadmin:5050      # Web admin UI
├── metabase-compose.yml   # Analytics
└── nginx-compose.yml     # Reverse proxy

services/
├── flask-a/:5000       → flask_a_db
├── flask-b/:5001       → flask_b_db
```

### Service Ports
| Service | Port | Via NGINX |
|---------|------|----------|
| NGINX | 8080 | http://localhost:8080 |
| Flask-A | 5000 | http://localhost:8080/flask-a/ |
| Flask-B | 5001 | http://localhost:8080/flask-b/ |
| PostgreSQL | 5432 | - (internal only) |
| pgAdmin | 5050 | http://localhost:5050 (direct) |

---

## pgAdmin Database Management

### Overview
pgAdmin provides a web-based interface for PostgreSQL database management.

### Access
- **URL**: http://localhost:5050
- **Email**: admin@example.com
- **Password**: password
- **Port**: 5050 (direct access, not via NGINX)

### Configuration
- **PostgreSQL Host**: localhost
- **PostgreSQL Port**: 5432
- **Database**: mydb
- **Username**: user
- **Password**: password

### Adding a Server
1. Login to pgAdmin at http://localhost:5050
2. Click "Add New Server"
3. Fill connection form:
   - Name: PostgreSQL (any label)
   - Host: localhost
   - Port: 5432
   - Database: mydb
   - Username: user
   - Password: password
4. Click "Save"

### Features
- Query Tool (SQL editor)
- Schema Browser (tables, views, functions)
- Visual Query Builder
- Backup/Restore
- Dashboard & Monitoring

---

## Database Auto-Creation

### Concept
Each Flask app declares its database in `.env`, and databases are automatically created when the app starts.

### App .env Variables
Each app in `services/<app>/.env` declares:
```bash
APP_NAME=flask-a
APP_PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flask_a_db      # Database to create
DB_USER=user           # Database user
DB_PASSWORD=password   # Database password
```

### ensure_databases() Function
Located in `scripts/manage.sh`:
```bash
ensure_databases() {
    # Reads DB_NAME from each app's .env
    # Creates database if not exists:
    #   CREATE DATABASE <DB_NAME>;
}
```

### How It Works
1. When starting any Flask app (`./manage.sh start flask-a`)
2. `ensure_databases()` is called
3. Reads `.env` from each app in `services/*/.env`
4. Creates databases that don't exist in PostgreSQL

### Adding New App with Database
1. Copy template: `cp services/flask-a services/flask-new`
2. Edit `.env`: Set `DB_NAME=flask_new_db`
3. Start app: `./manage.sh start flask-new`
4. Database `flask_new_db` auto-created