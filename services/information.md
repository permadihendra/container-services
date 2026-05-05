## Repository Overview

This repository serves as a **containerized microservices architecture** for managing Docker/Podman containers with Docker Compose compatibility. It provides a complete stack for hosting a Flask application with PostgreSQL database support and NGINX reverse proxy, optimized for vector data operations via the pgvector extension.

### Key Components

#### 1. PostgreSQL with pgvector
- **Container**: Uses the `ankane/pgvector` image for vector database capabilities
- **Persistence**: Data is stored in the `./postgres-data` volume for persistence across container restarts
- **Initialization**: The `init.sql` file creates the `vector` extension for advanced vector operations
- **Configuration**: All settings are managed via the `.env` file including port mappings and database credentials

#### 2. Flask Application
- **Container**: Based on Python 3.12-slim image with minimal base size
- **Functionality**: Provides a RESTful API with:
  - A health check endpoint at `/`
  - File upload endpoint at `/upload` with storage in `./app/uploads`
- **Database**: Connects to PostgreSQL via environment variable `DATABASE_URL`
- **Dependencies**: Requires `psycopg2` (currently missing from `requirements.txt`)

#### 3. NGINX Reverse Proxy
- **Container**: Uses the latest NGINX image for efficient request routing
- **Routing**: Directs all HTTP traffic to the Flask application on port 5000
- **Headers**: Properly sets proxy headers for client identification
- **Port Mapping**: Listens on host port 80 for incoming traffic

### Architecture
- **Orchestration**: Uses Podman Compose (Docker Compose compatible) for service management
- **Service Isolation**: Each component runs in its own container with defined dependencies
- **Versioning**: All compose files use version 3.9 for compatibility

### Current State
- The project is in early development stages
- Missing documentation for production deployment
- `requirements.txt` is incomplete (lacks `psycopg2`)
- Backup Dockerfile (`Dockerfile.bak`) suggests experimental custom PostgreSQL builds

### Recommendations
1. Add `psycopg2` to `requirements.txt` for database connectivity
2. Create comprehensive documentation for deployment and configuration
3. Consider adding Docker health checks for improved service reliability
4. Implement proper security headers in NGINX for production use
5. Explore automated backup solutions for PostgreSQL data