import os

from flask import Flask, jsonify

app = Flask(__name__)

APP_PORT = int(os.getenv("APP_PORT", 5000))
APP_NAME = os.getenv("APP_NAME", "Flask App")
DEBUG = os.getenv("FLASK_DEBUG", "0") == "1"


@app.route("/")
def home():
    return f"{APP_NAME} is running."


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT, debug=DEBUG)
