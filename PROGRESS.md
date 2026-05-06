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

### How to Add New App

1. Copy template: `cp -r services/flask-a services/flask-new`
2. Edit `.env`: Set `DB_NAME=flask_new_db`, `APP_PORT=5002`
3. Start: `./manage.sh start flask-new`
4. Database `flask_new_db` auto-created in PostgreSQL

### What's Next
- Full compose down/up workflow verified
- Script automation ready
- Database auto-creation from .env