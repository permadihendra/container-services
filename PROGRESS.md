## Progress

### Previous Work (Completed)
- Created compose files (flask-pg-compose.yml, metabase-compose.yml, nginx-compose.yml)
- Fixed volume syntax issues in all compose files
- Successfully validated compose files with nerdctl compose config
- Started all services with nerdctl compose up
- Fixed nginx port to 8080 (port 80 requires root)
- Fixed Metabase startup issue by adding hostname mapping

### Current Work: Refactoring for Reusability - COMPLETED

**Goal:** Create a reusable app structure that supports multiple instances (flask-a, flask-b) from a single template.

### Implementation Results

| Step | Status |
|------|--------|
| Create common/docker-base.Dockerfile | DONE |
| Create flask-app-template/ structure | DONE |
| Create flask-a/ instance | DONE |
| Create flask-b/ instance | DONE |
| Test deployment for flask-a | DONE |
| Test deployment for flask-b | DONE |
| Test NGINX routing | DONE |
| PostgreSQL integration | DONE |
| Unified start command | DONE |
| Dynamic app discovery | DONE |
| Database auto-creation | DONE |

### Script Commands (manage.sh)

| Command | Description |
|---------|-------------|
| `./manage.sh start` | Show available services |
| `./manage.sh start <name>` | Start specific service (flask-a, nginx, etc) |
| `./manage.sh start-all` | Start all services |
| `./manage.sh start-dev` | Start dev container with hot reload (`--source /path`) |
| `./manage.sh stop <name>` | Stop specific service |
| `./manage.sh stop-dev` | Stop dev container (`<app-name>`) |
| `./manage.sh stop-all` | Stop all services |
| `./manage.sh status` | Show running containers |
| `./manage.sh test` | Run all tests |

### Final Structure

```
services/
├── common/
│   └── docker-base.Dockerfile       # Base image with uv
├── flask-app-template/           # Template (DON'T modify per app)
│   ├── compose.yml
│   ├── Dockerfile
│   ├── app/
│   │   └── main.py
│   ├── requirements.txt
│   └── .env.example
├── flask-a/                    # Instance A
│   ├── compose.yml
│   ├── Dockerfile
│   ├── app/
│   │   └── main.py
│   ├── requirements.txt
│   └── .env
└── flask-b/                    # Instance B
    ├── compose.yml
    ├── Dockerfile
    ├── app/
    │   └── main.py
    ├── requirements.txt
    └── .env
```

### Test Results

```bash
# Flask apps directly
$ curl http://127.0.0.1:5000/
flask-a is running.

$ curl http://127.0.0.1:5001/
flask-b is running.

# Via NGINX reverse proxy (port 8080)
$ curl http://localhost:8080/
flask-a is running.

$ curl http://localhost:8080/flask-a/
flask-a is running.

$ curl http://localhost:8080/flask-b/
flask-b is running.

# PostgreSQL integration test
$ curl http://127.0.0.1:5000/db-test
{"status":"ok","version":"PostgreSQL 14.22..."}

$ curl http://127.0.0.1:5001/db-test
{"status":"ok","version":"PostgreSQL 14.22..."}

# Via NGINX
$ curl http://localhost:8080/flask-a/db-test
$ curl http://localhost:8080/flask-b/db-test
```

### Key Technical Notes

- Used `nerdctl commit` to build images (buildkit not available in this environment)
- Build involves: start container → install uv → copy requirements → install packages → commit image
- Each instance uses different port (5000, 5001) to avoid conflicts
- main.py uses `APP_PORT` environment variable for port configuration
- Used host network mode (--network host) due to iptables limitations
- Each app has its own database (flask_a_db, flask_b_db)
- Main.py includes DB connection and health check endpoints
- PostgreSQL credentials: user/password@localhost:5432

### Database Configuration

Each app's `.env` declares database connection:
```bash
# services/flask-a/.env
DB_NAME=flask_a_db
DB_USER=user
DB_PASSWORD=password
```

`ensure_databases()` in manage.sh:
- Scans all apps in `services/*/.env`
- Creates databases automatically if not exists
- Uses main PostgreSQL database (mydb) to create child databases

### PostgreSQL with pgAdmin

- **File**: `compose-service/postgres-compose.yml`
- **pgAdmin URL**: http://localhost:5050
- **pgAdmin Credentials**: admin@example.com / password
- **PostgreSQL**: localhost:5432 (user / password)

### NGINX Reverse Proxy for pgAdmin

Since the refactoring goal is consistency, NGINX serves as single entry point on port 8080 for Flask apps. pgAdmin is accessed directly:

| Service | Internal | Via NGINX (8080) | Direct Access |
|---------|----------|-----------------|---------------|
| Flask-A | 5000 | http://localhost:8080/flask-a/ | - |
| Flask-B | 5001 | http://localhost:8080/flask-b/ | - |
| pgAdmin | 5050 | - | http://localhost:5050 |

Note: pgAdmin is accessed directly on port 5050 (not via nginx) because:
- nginx runs in host network mode with different network namespace
- pgAdmin uses port 5050 which requires custom PGADMIN_LISTEN_PORT env var
- Path rewriting issues prevent proxying with location prefix

### How to Add New App

1. Copy template: `cp -r services/flask-a services/flask-new`
2. Edit `.env`: Set `DB_NAME=flask_new_db`, `APP_PORT=5002`
3. Start: `./manage.sh start flask-new`
4. Database `flask_new_db` auto-created in PostgreSQL

### What's Next
- [x] Dev Mode: volume mount + hot reload for external projects
- [x] Dev Mode: template scaffolding (flask, react)
- [x] Dev Mode: auto-port assignment and nginx route management
- [x] Dev Mode: interactive project creation
- [x] Dev Mode: end-to-end test (scaffold → start → hot reload → stop)
- [x] Dev Mode: DEPENDS_ON — selective infrastructure startup
- [x] Dev Mode: .env.example with Laravel-style documentation
- [x] Dev Mode: stop_all handles dev containers (label-based)
- [ ] Dev Mode: push feat/dev-mode → main

## Dev Mode Implementation

### Files Created/Modified

| File | Change |
|------|--------|
| `scripts/dev.py` | **New** - Python dev mode manager |
| `scripts/manage.sh` | Added `start-dev`, `stop-dev` commands |
| `services/templates/flask/` | **New** - Flask template |
| `services/templates/react/` | **New** - React (Vite) template |

### Dev Mode Flow
1. `./manage.sh start-dev --source /path/to/project`
2. If path doesn't exist → interactive prompt (flask/react)
3. `manage.sh` ensures base image exists
4. Delegates to `dev.py start --source <path>`
5. `dev.py` reads `.env`, starts container with volume mount + `FLASK_DEBUG=1`
6. Auto-adds nginx route: `/{app_name}/ → localhost:{port}`

### Dev Mode Test Results

```
$ # Scaffold new project
$ ./manage.sh start-dev --source ~/my-python-projects/flask-dev-test
[OK] Created /home/hendra/my-python-projects/flask-dev-test/.env
[OK] Scaffolded flask project at /home/hendra/my-python-projects/flask-dev-test

$ # Start dev container
$ ./manage.sh start-dev --source ~/my-python-projects/flask-dev-test
[OK] Nginx route /flask-dev-test/ added (port 5002)
[OK] Dev container 'flask-dev-test' started on port 5002

$ # Verify endpoints
$ curl http://localhost:5002/
flask-dev-test is running.

$ curl http://localhost:5002/health
{"status": "healthy"}

$ curl http://localhost:8080/flask-dev-test/
flask-dev-test is running.

$ curl http://localhost:8080/flask-dev-test/health
{"status": "healthy"}

$ # Add new route to main.py → auto-reload detected
* Detected change in '/app/app/main.py', reloading
* Restarting with stat

$ curl http://localhost:5002/version
2.0.0

$ # Stop and cleanup
$ ./manage.sh stop-dev flask-dev-test
[OK] Nginx route /flask-dev-test/ removed
[OK] Dev container 'flask-dev-test' stopped and cleaned up
```

Issues found & fixed during testing:
- `uv pip install` needed `--system` flag (no venv in base image)
- Nginx route insertion logic placed route after the http block closing brace; fixed to insert inside server block

### Technical Notes
- Uses `services/common:docker-base` as base image
- Dependencies installed at container start via `uv pip install --system`
- Hot reload via Flask's `debug=True` mode
- Nginx routes managed with comment markers (clean add/remove)
- Port assignments tracked in `.dev-port-registry.json` (gitignored)