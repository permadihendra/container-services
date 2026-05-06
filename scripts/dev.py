#!/usr/bin/env python3
"""Dev mode manager for container-services.

Usage:
    ./scripts/dev.py scaffold --type flask --dest /path/to/project
    ./scripts/dev.py start --source /path/to/project
    ./scripts/dev.py stop --name app_name
    ./scripts/dev.py nginx-add --name app_name --port PORT
    ./scripts/dev.py nginx-remove --name app_name
"""

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
from pathlib import Path
from string import Template

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_DIR = SCRIPT_DIR.parent
SERVICES_DIR = PROJECT_DIR / "services"
TEMPLATES_DIR = SERVICES_DIR / "templates"
COMPOSE_DIR = PROJECT_DIR / "compose-service"
NGINX_CONF = COMPOSE_DIR / "nginx.conf"
PORT_REGISTRY = PROJECT_DIR / ".dev-port-registry.json"

BASE_IMAGE = "services/common:docker-base"
NGINX_SERVICE = "compose-service-nginx-1"


def sh(cmd: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, shell=True, check=check,
                          capture_output=True, text=True)


def err(msg: str):
    print(f"[ERROR] {msg}", file=sys.stderr)


def ok(msg: str):
    print(f"[OK] {msg}")


def warn(msg: str):
    print(f"[WARN] {msg}")


#
# Template scaffolding
#

def scaffold(type_: str, dest: str):
    src = TEMPLATES_DIR / type_
    dst = Path(dest).resolve()

    if not src.exists():
        err(f"Template type '{type_}' not found at {src}")
        sys.exit(1)

    if dst.exists():
        warn(f"Directory {dst} already exists. Overwrite? [y/N] ", end="")
        answer = input().strip().lower()
        if answer != "y":
            print("Aborted.")
            return

    shutil.copytree(src, dst, dirs_exist_ok=True)

    # Generate .env from .env.example with defaults
    env_example = dst / ".env.example"
    env_file = dst / ".env"
    if env_example.exists() and not env_file.exists():
        shutil.copy(env_example, env_file)
        ok(f"Created {env_file}")

    # Assign a port
    port = assign_port(dst.name)
    update_env(dst, "APP_PORT", str(port))
    update_env(dst, "APP_NAME", dst.name)

    if type_ == "flask":
        db_name = dst.name.replace("-", "_") + "_db"
        update_env(dst, "DB_NAME", db_name)

    ok(f"Scaffolded {type_} project at {dst}")
    print(f"  Next: edit {dst}/.env and run:")
    print(f"  ./scripts/manage.sh start-dev --source {dst}")


def update_env(project_dir: Path, key: str, value: str):
    env_file = project_dir / ".env"
    if not env_file.exists():
        return
    content = env_file.read_text()
    if re.search(rf"^{key}=", content, re.MULTILINE):
        content = re.sub(rf"^{key}=.*", f"{key}={value}", content, flags=re.MULTILINE)
    else:
        content += f"\n{key}={value}\n"
    env_file.write_text(content)


#
# Port management
#

def load_registry() -> dict:
    if PORT_REGISTRY.exists():
        return json.loads(PORT_REGISTRY.read_text())
    return {}


def save_registry(registry: dict):
    PORT_REGISTRY.write_text(json.dumps(registry, indent=2))


def get_used_ports() -> set:
    used = set()
    # From existing dev registry
    registry = load_registry()
    for entry in registry.values():
        used.add(entry["port"])
    # From known compose services
    used.update({5432, 8080, 3000, 5050, 5000, 5001})
    return used


def assign_port(name: str) -> int:
    registry = load_registry()
    if name in registry:
        return registry[name]["port"]

    used = get_used_ports()
    port = 5002
    while port in used:
        port += 1

    registry[name] = {"port": port, "type": "dev"}
    save_registry(registry)
    return port


def release_port(name: str):
    registry = load_registry()
    registry.pop(name, None)
    save_registry(registry)


#
# .env loader
#

def load_env(source_dir: Path) -> dict:
    env_file = source_dir / ".env"
    env = {}
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            env[key.strip()] = val.strip()
    return env


#
# Validation
#

def validate(source_dir: Path):
    if not source_dir.exists():
        err(f"Source directory not found: {source_dir}")
        return False

    env = load_env(source_dir)
    required = {"APP_NAME", "APP_PORT"}
    missing = required - set(env.keys())
    if missing:
        err(f"Missing required env vars in {source_dir / '.env'}: {', '.join(missing)}")
        return False

    app_type = env.get("APP_TYPE", "flask")
    if app_type == "flask":
        app_dir = source_dir / "app"
        if not (source_dir / "requirements.txt").exists():
            err(f"Missing requirements.txt in {source_dir}")
            return False
        if not app_dir.exists() or not (app_dir / "main.py").exists():
            err(f"Missing app/main.py in {source_dir}")
            return False
    elif app_type == "react":
        if not (source_dir / "package.json").exists():
            err(f"Missing package.json in {source_dir}")
            return False

    return True


#
# Container lifecycle
#

def start(source_dir: str):
    source_path = Path(source_dir).resolve()

    if not validate(source_path):
        sys.exit(1)

    env = load_env(source_path)
    app_name = env["APP_NAME"]
    app_port = int(env["APP_PORT"])
    app_type = env.get("APP_TYPE", "flask")

    # Check if already running
    result = sh(f"nerdctl ps --filter name=^{app_name}$ --format '{{{{.Names}}}}'", check=False)
    if app_name in result.stdout:
        warn(f"Container '{app_name}' already running")
        return

    if app_type == "flask":
        _start_flask(source_path, app_name, app_port, env)
    elif app_type == "react":
        _start_react(source_path, app_name, app_port, env)
    else:
        err(f"Unknown app type: {app_type}")
        sys.exit(1)

    # Auto-add nginx route
    _nginx_add(app_name, app_port)
    ok(f"Dev container '{app_name}' started on port {app_port}")
    print(f"  http://localhost:{app_port}")
    print(f"  http://localhost:8080/{app_name}/")


def _start_flask(source_dir: Path, app_name: str, port: int, env: dict):
    db_name = env.get("DB_NAME", f"{app_name.replace('-', '_')}_db")

    cmd = (
        f'nerdctl run -d --name "{app_name}" '
        f"--network host "
        f'-v "{source_dir}/app:/app/app" '
        f'-v "{source_dir}/requirements.txt:/app/requirements.txt" '
        f"-e APP_NAME={app_name} "
        f"-e APP_PORT={port} "
        f"-e FLASK_DEBUG=1 "
        f"-e DB_HOST=localhost "
        f"-e DB_PORT=5432 "
        f"-e DB_NAME={db_name} "
        f"-e DB_USER=user "
        f"-e DB_PASSWORD=password "
        f"{BASE_IMAGE} "
        f'bash -c "uv pip install --system -r /app/requirements.txt && python /app/app/main.py"'
    )
    sh(cmd)


def _start_react(source_dir: Path, app_name: str, port: int, env: dict):
    # React runs on the host OS with Node.js
    # We just cd into the dir and run npm install + npm run dev
    api_url = env.get("VITE_API_URL", "http://localhost:8080")
    cmd = (
        f'cd "{source_dir}" && '
        f"npm install && "
        f"VITE_API_URL={api_url} npm run dev"
    )
    # Run in background with nohup
    sh(f'nohup bash -c \'{cmd}\' > "{source_dir}/dev.log" 2>&1 &')
    ok(f"React dev server starting... check {source_dir}/dev.log for output")


def stop(app_name: str):
    sh(f"nerdctl rm -f {app_name} 2>/dev/null || true", check=False)
    # Kill any host Node.js dev server for this project
    sh(
        f'pkill -f "vite.*{app_name}" 2>/dev/null || true',
        check=False,
    )
    _nginx_remove(app_name)
    release_port(app_name)
    ok(f"Dev container '{app_name}' stopped and cleaned up")


#
# Nginx route management
#

NGINX_MARKER_START = "    # --- dev-mode route: {name} ---"
NGINX_MARKER_END = "    # --- end dev-mode route: {name} ---"
NGINX_ROUTE_TEMPLATE = Template(
    """    # --- dev-mode route: ${name} ---
        location /${name}/ {
            proxy_pass http://127.0.0.1:${port}/;
            proxy_set_header Host $$host;
            proxy_set_header X-Real-IP $$remote_addr;
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $$scheme;
        }
    # --- end dev-mode route: ${name} ---""")

NGINX_ROUTE_PATTERN = re.compile(
    r"    # --- dev-mode route: (\S+) ---.*?"
    r"    # --- end dev-mode route: \1 ---",
    re.DOTALL,
)


def _nginx_add(name: str, port: int):
    if not NGINX_CONF.exists():
        return

    content = NGINX_CONF.read_text()

    # Remove existing route for this name if present
    content = NGINX_ROUTE_PATTERN.sub("", content)

    # Insert inside the server block, before the closing '}\n}'
    route = NGINX_ROUTE_TEMPLATE.safe_substitute(name=name, port=port)
    content = content.rstrip()
    # Replace last '}\n}' (end of server + end of http) with route + '}\n}'
    if content.endswith("}"):
        # Find the last occurrence of closing braces
        last_brace = content.rfind("}")
        second_last_brace = content.rfind("}", 0, last_brace - 1)
        before = content[:second_last_brace]
        after = content[second_last_brace:]
        content = before + route + "\n" + after
    else:
        content += "\n" + route + "\n"

    NGINX_CONF.write_text(content)
    sh(f"nerdctl exec {NGINX_SERVICE} nginx -s reload 2>/dev/null || "
       f"nerdctl restart {NGINX_SERVICE} 2>/dev/null || true", check=False)
    ok(f"Nginx route /{name}/ added (port {port})")


def _nginx_remove(name: str):
    if not NGINX_CONF.exists():
        return

    content = NGINX_CONF.read_text()
    pattern = re.compile(
        r"    # --- dev-mode route: " + re.escape(name) + r" ---.*?"
        r"    # --- end dev-mode route: " + re.escape(name) + r" ---\n?",
        re.DOTALL,
    )
    content = pattern.sub("", content)
    NGINX_CONF.write_text(content)
    sh(f"nerdctl exec {NGINX_SERVICE} nginx -s reload 2>/dev/null || "
       f"nerdctl restart {NGINX_SERVICE} 2>/dev/null || true", check=False)
    ok(f"Nginx route /{name}/ removed")


def list_running():
    result = sh("nerdctl ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}'", check=False)
    print("Running dev containers:")
    print(result.stdout)


#
# Main CLI
#

def main():
    parser = argparse.ArgumentParser(
        description="Dev mode manager for container-services")
    sub = parser.add_subparsers(dest="command", required=True)

    # scaffold
    p_scaffold = sub.add_parser("scaffold", help="Scaffold a new project from template")
    p_scaffold.add_argument("--type", required=True, choices=["flask", "react"])
    p_scaffold.add_argument("--dest", required=True, help="Destination directory")

    # start
    p_start = sub.add_parser("start", help="Start dev container for a project")
    p_start.add_argument("--source", required=True, help="Project source directory")

    # stop
    p_stop = sub.add_parser("stop", help="Stop dev container")
    p_stop.add_argument("--name", required=True, help="Container/app name")

    # nginx-add
    p_na = sub.add_parser("nginx-add", help="Add nginx route for a dev project")
    p_na.add_argument("--name", required=True)
    p_na.add_argument("--port", required=True, type=int)

    # nginx-remove
    p_nr = sub.add_parser("nginx-remove", help="Remove nginx route for a dev project")
    p_nr.add_argument("--name", required=True)

    # list
    sub.add_parser("list", help="List running dev containers")

    args = parser.parse_args()

    if args.command == "scaffold":
        scaffold(args.type, args.dest)
    elif args.command == "start":
        start(args.source)
    elif args.command == "stop":
        stop(args.name)
    elif args.command == "nginx-add":
        _nginx_add(args.name, args.port)
    elif args.command == "nginx-remove":
        _nginx_remove(args.name)
    elif args.command == "list":
        list_running()


if __name__ == "__main__":
    main()
