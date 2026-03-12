from flask import Flask, jsonify
import redis
import os
import time

app = Flask(__name__)

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))

def get_redis():
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

@app.route("/health")
def health():
    try:
        r = get_redis()
        r.ping()
        return jsonify({"status": "healthy", "redis": "connected"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503

@app.route("/")
def index():
    return jsonify({"message": "REST API is running", "version": "1.0.0"})

@app.route("/api/visits")
def visits():
    try:
        r = get_redis()
        count = r.incr("visit_count")
        return jsonify({"visits": count, "timestamp": time.time()})
    except Exception as e:
        return jsonify({"error": str(e)}), 503

@app.route("/api/data")
def data():
    return jsonify({
        "items": [{"id": i, "value": f"item_{i}"} for i in range(1, 6)],
        "total": 5
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
