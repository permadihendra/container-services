import os

import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "database": os.getenv("DB_NAME", "flask_a_db"),
    "user": os.getenv("DB_USER", "user"),
    "password": os.getenv("DB_PASSWORD", "password"),
}


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


@app.route("/")
def home():
    return f"{os.getenv('APP_NAME', 'Flask App')} is running."


@app.route("/health")
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500


@app.route("/db-test")
def db_test():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        cursor.close()
        conn.close()
        return jsonify({"status": "ok", "version": version[0]}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    port = int(os.getenv("APP_PORT", "5000"))
    app.run(host="0.0.0.0", port=port)