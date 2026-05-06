# DIY Container Services

> A friendly, production-ready microservices toolkit. Run Flask applications, PostgreSQL, pgAdmin, Metabase, and NGINX — all containerized, all under your control.

Whether you're building your first microservice or your tenth, this project gives you a solid foundation. Spin up multiple Flask apps from a single template, manage them with one command, and even run your own external projects with hot reload during development.

---

## Table of Contents

- [What You Get](#what-you-get)
- [Architecture at a Glance](#architecture-at-a-glance)
- [Directory Structure](#directory-structure)
- [Quick Start](#quick-start)
- [Everyday Commands](#everyday-commands)
- [Services Breakdown](#services-breakdown)
  - [Flask Applications](#flask-applications)
  - [PostgreSQL & pgAdmin](#postgresql--pgadmin)
  - [NGINX Reverse Proxy](#nginx-reverse-proxy)
  - [Metabase Analytics](#metabase-analytics)
- [Dev Mode: Hot Reload for Your Own Projects](#dev-mode-hot-reload-for-your-own-projects)
- [Database Configuration](#database-configuration)
- [API Endpoints](#api-endpoints)
- [Troubleshooting](#troubleshooting)
- [Scripts Reference](#scripts-reference)

---

## What You Get

Here's everything that comes out of the box:

- **Multi-App Support** — Run multiple Flask applications (flask-a, flask-b) from a single shared template. Add new ones in seconds.
- **PostgreSQL + pgAdmin** — A shared database server with a web-based admin panel at your fingertips.
- **NGINX Reverse Proxy** — One entry point (`localhost:8080`) that routes to all your services.
- **Metabase Analytics** — Built-in business intelligence dashboard.
- **Dev Mode** — Run your own Python or React projects with hot reload. No image building required.
- **Smart Scripts** — One command to start everything. Databases are auto-created. Builds are skipped if nothing changed.
- **uv Package Manager** — Fast Python dependency installation.

### Technology Stack

| Component | What We Use |
|-----------|-------------|
| Runtime | Python 3.12-slim |
| Package Manager | uv |
| Web Server | NGINX (latest) |
| Database | PostgreSQL 14 |
| Admin UI | pgAdmin 4 |
| Analytics | Metabase (latest) |
| Container Runtime | nerdctl / Podman 2.2.2 |

---

## Architecture at a Glance

Here's how the services fit together:

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
     │   Flask-A      │   │   Flask-B      │   │   pgAdmin      │
     │   (port 5000) │   │   (port 5001)  │   │  (port 5050)   │
     └───────┬───────┘   └───────┬───────┘   └─────────────────┘
            │                   │                    │
            └─────────┬─────────┘                    │
                      ▼                             │
           ┌────────────────────┐                    │
           │   PostgreSQL        │◄───────────────────┘
           │   (port 5432)       │
           ├────────────────────┤
           │ flask_a_db         │ ← flask-a
           │ flask_b_db        │ ← flask-b
           │ mydb             │ ← pgAdmin
           └────────────────────┘
```

The idea is simple: NGINX sits at the front, routing traffic to the right service. PostgreSQL sits at the back, shared by everyone. Everything in between is just an app waiting for your code.

---

## Directory Structure

```
container-services/
├── compose-service/            # Compose files & infrastructure
│   ├── nginx-compose.yml       # NGINX service
│   ├── nginx.conf              # NGINX routing rules
│   ├── postgres-compose.yml    # PostgreSQL + pgAdmin
│   ├── metabase-compose.yml    # Metabase analytics
│   └── .env                    # Shared environment variables
│
├── services/                   # Flask applications
│   ├── common/                 # Shared base image
│   ├── flask-app-template/     # Reusable template (don't modify this one!)
│   ├── flask-a/                # Your first app instance
│   ├── flask-b/                # Your second app instance
│   └── templates/              # Starter templates for dev mode
│       ├── flask/              #   → Flask (Python)
│       └── react/              #   → React (Vite)
│
├── scripts/                    # The brains of the operation
│   ├── manage.sh               # Build, deploy, manage everything
│   ├── dev.py                  # Dev mode manager (called by manage.sh)
│   └── test.sh                 # Automated testing
│
├── PLANNING.md                 # Architecture decisions and design docs
├── PROGRESS.md                 # What we've done and what's next
├── README.md                   # You are here
└── information.md              # Detailed configuration reference
```

---

## Quick Start

Let's get you up and running in five minutes.

### What You'll Need

Before we begin, make sure you have these tools installed:

```bash
nerdctl    # Container runtime (also works with docker/podman)
curl       # For testing endpoints
bash       # For running scripts
```

> If you don't have `nerdctl` yet, [check out their installation guide](https://github.com/containerd/nerdctl/tree/main).

### Start Everything

```bash
# The easy way — one command to rule them all:
./scripts/manage.sh start-all

# Or, if you prefer manual control:
cd compose-service
nerdctl compose -f postgres-compose.yml -f metabase-compose.yml -f nginx-compose.yml up -d
```

### Verify It's Working

```bash
# The automatic way:
./scripts/test.sh all

# Or check each service manually:
curl http://localhost:8080/           # flask-a (via NGINX)
curl http://localhost:8080/flask-a/   # flask-a directly
curl http://localhost:8080/flask-b/   # flask-b
curl http://localhost:3000/           # Metabase
curl http://localhost:5050/           # pgAdmin (you'll get redirected to the login page)
```

---

## Everyday Commands

Once you're up and running, these are the commands you'll use most often:

```bash
# Managing services
./scripts/manage.sh status           # What's running right now?
./scripts/manage.sh start flask-a    # Start one service
./scripts/manage.sh stop flask-a     # Stop one service
./scripts/manage.sh stop-all         # Stop everything

# Working with infrastructure
./scripts/manage.sh start postgres   # Start PostgreSQL + pgAdmin
./scripts/manage.sh start nginx      # Start the reverse proxy
./scripts/manage.sh start metabase   # Start analytics

# Building apps
./scripts/manage.sh build flask-a    # Build or rebuild an app image

# Development mode (hot reload)
./scripts/manage.sh start-dev --source /path/to/my-project
./scripts/manage.sh stop-dev my-project

# Testing and logs
./scripts/manage.sh test             # Run all tests
./scripts/manage.sh logs flask-a     # See what's happening
./scripts/manage.sh help             # Show all available commands
```

Need to see what services are available?

```bash
./scripts/manage.sh start
# This will list all Flask apps and compose services it knows about.
```

---

## Services Breakdown

Let's walk through each service and what it does.

### Flask Applications

Each Flask app is fully isolated. It gets its own port, its own database, and its own dependencies. They all share the same base image, so builds are fast.

#### Flask-A

- **Access**: http://localhost:5000 or http://localhost:8080/flask-a/
- **Database**: `flask_a_db`
- **Depends on**: flask, psycopg2-binary

#### Flask-B

- **Access**: http://localhost:5001 or http://localhost:8080/flask-b/
- **Database**: `flask_b_db`
- **Depends on**: flask, flask-sqlalchemy, sqlalchemy, psycopg2-binary

#### Adding a New App

Want to add flask-c? It's just a few steps:

```bash
# 1. Copy an existing app as your starting point
cp -r services/flask-a services/flask-c

# 2. Give it a unique identity
# Edit services/flask-c/.env:
#   APP_NAME=flask-c
#   APP_PORT=5002
#   DB_NAME=flask_c_db

# 3. Tell NGINX about it
# Add to compose-service/nginx.conf:
#   location /flask-c/ {
#       proxy_pass http://localhost:5002/;
#   }

# 4. Build and go
./scripts/manage.sh build flask-c
./scripts/manage.sh start flask-c
```

### PostgreSQL & pgAdmin

A single PostgreSQL instance serves all your apps, each with its own isolated database. pgAdmin gives you a web UI to manage everything.

- **PostgreSQL**: `localhost:5432` (user: `user`, password: `password`)
- **pgAdmin**: http://localhost:5050 (email: `admin@example.com`, password: `password`)

#### Connecting pgAdmin to PostgreSQL

1. Open http://localhost:5050 in your browser
2. Log in with `admin@example.com` / `password`
3. Click **Add New Server**
4. On the **General** tab, give it a name (anything you like)
5. On the **Connection** tab, fill in:
   - Host: `localhost`
   - Port: `5432`
   - Database: `mydb`
   - Username: `user`
   - Password: `password`
6. Click **Save**

Once connected, you can browse tables, run SQL queries, and manage your databases — all from your browser.

### NGINX Reverse Proxy

NGINX sits at the front door (port 8080) and routes requests to the right service. No more remembering which port each app runs on.

| Route | Goes To |
|-------|---------|
| `/` | flask-a (default) |
| `/flask-a/` | flask-a (port 5000) |
| `/flask-b/` | flask-b (port 5001) |

### Metabase Analytics

Metabase gives you a business intelligence dashboard for exploring your data.

- **URL**: http://localhost:3000
- **Database**: `metabase_db`
- **Credentials**: user / password

---

## Dev Mode: Hot Reload for Your Own Projects

This is where things get interesting. Instead of baking your code into a container image every time you make a change, you can mount your project directory directly and get instant hot reload.

### How It Works

| Aspect | Production Mode (`start`) | Dev Mode (`start-dev`) |
|--------|---------------------------|------------------------|
| Image | Your code is baked in | Uses the base image only |
| Code delivery | Built into the image | Mounted as a volume |
| Dependencies | Installed once at build time | Installed each time you start |
| Hot reload | Not available | Yes, via `FLASK_DEBUG=1` |
| Project location | Must live in `services/` | Anywhere on your machine |

### Starting a Project

```bash
# New project? Just point to where you want it:
./scripts/manage.sh start-dev --source /path/to/my-new-project

# You'll be asked: "Flask or React?"
# Pick one, and the template will be scaffolded automatically.
# Your .env file will be populated with sensible defaults.

# Already have a project?
./scripts/manage.sh start-dev --source /path/to/existing-project
```

### What Happens When You Run It

1. **manage.sh** reads your `.env` file and checks what infrastructure you need (database, proxy, etc.)
2. It starts only what's required — nothing more
3. **dev.py** takes over: it mounts your code as a volume and starts the container with `FLASK_DEBUG=1`
4. An NGINX route is automatically added so you can access your app at `http://localhost:8080/your-app-name/`
5. Every time you save a file, Flask restarts automatically

### Stopping a Project

```bash
./scripts/manage.sh stop-dev my-project

# This cleans up:
#   - The running container
#   - The NGINX route
#   - The port assignment
```

### Project Templates

Don't want to start from scratch? We've got you covered:

- **Flask template** at `services/templates/flask/` — includes a basic app with health check endpoints and PostgreSQL support
- **React template** at `services/templates/react/` — a Vite + React setup that's ready to go

### How Infrastructure Dependencies Work

Your project's `.env` file has a `DEPENDS_ON` field. This tells `start-dev` which infrastructure services need to be running:

```bash
# For a Flask app that needs a database:
DEPENDS_ON=postgres

# For a React app that needs nothing:
DEPENDS_ON=

# For something that needs everything:
DEPENDS_ON=postgres,nginx
```

Only the services you declare will be started. No waste, no confusion.

---

## Database Configuration

### How Databases Are Created

Databases are created automatically when you start an app. Here's the flow:

1. Each app in `services/<app>/.env` declares the database it needs
2. When you run `./manage.sh start flask-a`, it checks if that database exists
3. If not, it creates it. Simple as that.

```bash
# Example: services/flask-a/.env
DB_NAME=flask_a_db
DB_USER=user
DB_PASSWORD=password

# When you start the app:
./scripts/manage.sh start flask-a
# Output: [OK] Created database: flask_a_db
```

### Connection Details

| Property | Value |
|----------|-------|
| Host | localhost |
| Port | 5432 |
| Username | user |
| Password | password |
| Default Database | mydb |
| Connection String | `postgres://user:password@localhost:5432/mydb` |

---

## API Endpoints

Each Flask app exposes these endpoints:

| Endpoint | Method | What It Does | Returns |
|----------|--------|-------------|---------|
| `/` | GET | Home page | App name and status |
| `/health` | GET | Health check | JSON with database status |
| `/db-test` | GET | Database test | PostgreSQL version |

### Live Examples

```bash
# Home page
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

## Troubleshooting

Something not working? Here are the most common issues and how to fix them.

#### Container Won't Start

```bash
# Check what's happening inside
nerdctl logs <container-name>

# See if it's even there
nerdctl ps -a
```

#### Database Connection Failed

```bash
# Is PostgreSQL running?
nerdctl ps | grep postgres

# Can your app reach it?
curl http://localhost:5000/db-test
```

#### NGINX Routing Not Working

```bash
# Give it a kick
cd compose-service
nerdctl compose restart nginx

# See what NGINX thinks
nerdctl logs compose-service-nginx-1
```

#### pgAdmin Not Accessible

```bash
# Is pgAdmin running?
nerdctl ps | grep pgadmin

# What does its log say?
nerdctl logs compose-service-pgadmin-1

# Common culprit: port 80 permission denied
# Fix: set PGADMIN_LISTEN_PORT to something > 1024 (we use 5050)
```

### Service Ports Reference

| Service | Port | Container Name |
|---------|------|----------------|
| Flask-A | 5000 | flask-a |
| Flask-B | 5001 | flask-b |
| NGINX | 8080 | compose-service-nginx-1 |
| PostgreSQL | 5432 | compose-service-postgres-1 |
| pgAdmin | 5050 | compose-service-pgadmin-1 |
| Metabase | 3000 | compose-service-metabase-1 |

---

## Scripts Reference

### manage.sh — The One Script to Rule Them All

This is your main tool for managing the entire stack.

```bash
./scripts/manage.sh <command> [options]
```

| Command | Options | What It Does |
|---------|---------|-------------|
| `build-base` | — | Build the shared Python base image |
| `build` | `<app-name>` | Build a specific app's image |
| `start` | `<app> <port> <db>` | Start an app or compose service |
| `start-dev` | `--source <path>` | Start a project in dev mode (hot reload) |
| `start-all` | — | Build and start everything |
| `stop` | `<app-name>` | Stop a specific service |
| `stop-dev` | `<app-name>` | Stop a dev mode project |
| `stop-all` | — | Stop everything |
| `compose-up` | — | Start infrastructure services |
| `compose-down` | — | Stop infrastructure services |
| `status` | — | Show what's running |
| `test` | — | Run all tests |
| `logs` | `<app-name>` | View logs for a service |
| `help` | — | Show this list |

#### Real-World Examples

```bash
# First time setup
./scripts/manage.sh build-base

# Build your apps
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

# Start everything
./scripts/manage.sh start-all

# Work on a specific app
./scripts/manage.sh start flask-a 5000 flask_a_db

# Check on things
./scripts/manage.sh status
./scripts/manage.sh logs flask-a

# Clean up
./scripts/manage.sh stop flask-a
./scripts/manage.sh stop-all
```

### test.sh — Automated Testing

Run tests to make sure everything is working.

```bash
./scripts/test.sh <test-type>
```

| Test Type | What It Checks |
|-----------|----------------|
| `all` | Everything (default) |
| `containers` | Are all containers running? |
| `health` | Are the health endpoints responding? |
| `database` | Can the apps reach PostgreSQL? |
| `nginx` | Is NGINX routing correctly? |
| `metabase` | Is Metabase accessible? |
| `pgadmin` | Is pgAdmin accessible? |

#### Example Output

```
========================================
Running All Tests
========================================
=== Container Tests ===
[PASS] Container running: flask-a
[PASS] Container running: flask-b
[PASS] Container running: compose-service-nginx-1
[PASS] Container running: compose-service-postgres-1
[PASS] Container running: compose-service-pgadmin-1
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
=== pgAdmin Test ===
[PASS] pgAdmin login: http://localhost:5050/

========================================
Results: 17 passed, 0 failed
========================================
```

### Workflows

#### Development

```bash
# Start infrastructure
cd compose-service
nerdctl compose up -d

# Make changes to your app
# (edit services/flask-a/app/main.py)

# Rebuild and restart
./scripts/manage.sh build flask-a
./scripts/manage.sh stop flask-a
./scripts/manage.sh start flask-a 5000 flask_a_db

# Test your changes
./scripts/test.sh health
```

#### CI/CD

```bash
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

#### Full Deployment

```bash
# 1. Stop everything
./scripts/manage.sh stop-all

# 2. Rebuild
./scripts/manage.sh build flask-a
./scripts/manage.sh build flask-b

# 3. Start fresh
./scripts/manage.sh start-all

# 4. Verify
./scripts/test.sh all

# 5. Check the logs
./scripts/manage.sh logs flask-a
./scripts/manage.sh logs flask-b
```

---

## License

MIT License — do what you want with it.

## Contributing

Found a bug? Want a feature? contributions are warmly welcomed:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

*Built with curiosity, maintained with care.*
