import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)
UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Connect to PostgreSQL
db_url = os.getenv("DATABASE_URL")
conn = psycopg2.connect(db_url)
cursor = conn.cursor()


@app.route("/")
def home():
    return "Flask app connected to PostgreSQL + pgvector."


@app.route("/upload", methods=["POST"])
def upload():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400
    file = request.files["file"]
    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)
    return jsonify({"message": "File uploaded", "filename": file.filename})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
