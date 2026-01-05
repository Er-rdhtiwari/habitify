import os
import threading
from datetime import datetime, timezone
from typing import List, Dict, Any

from flask import Flask, jsonify, request, send_from_directory


def iso_now() -> str:
    """Return current UTC time in ISO 8601 format with trailing Z."""
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def create_app() -> Flask:
    app = Flask(__name__, static_folder="../static", static_url_path="")

    reminders: List[Dict[str, Any]] = []
    habits: List[Dict[str, Any]] = []
    reminder_seq = {"value": 1}
    habit_seq = {"value": 1}
    lock = threading.Lock()

    @app.route("/health", methods=["GET"])
    def health() -> Any:
        return jsonify({"status": "ok"})

    @app.route("/api/reminders", methods=["GET", "POST"])
    def reminders_handler() -> Any:
        nonlocal reminders
        if request.method == "GET":
            return jsonify(reminders)

        payload = request.get_json(force=True, silent=True) or {}
        with lock:
            reminder_id = payload.get("id")
            if reminder_id:
                for item in reminders:
                    if item["id"] == reminder_id:
                        item["title"] = payload.get("title", item["title"])
                        item["dueDate"] = payload.get("dueDate", item.get("dueDate"))
                        if "completed" in payload:
                            item["completed"] = bool(payload["completed"])
                        return jsonify(item), 200
                return jsonify({"error": "reminder not found"}), 404

            new_id = reminder_seq["value"]
            reminder_seq["value"] += 1
            reminder = {
                "id": new_id,
                "title": payload.get("title", "").strip() or "Untitled",
                "dueDate": payload.get("dueDate") or "",
                "completed": bool(payload.get("completed", False)),
                "createdAt": iso_now(),
            }
            reminders.append(reminder)
            return jsonify(reminder), 201

    @app.route("/api/habits", methods=["GET", "POST"])
    def habits_handler() -> Any:
        nonlocal habits
        if request.method == "GET":
            return jsonify(habits)

        payload = request.get_json(force=True, silent=True) or {}
        with lock:
            habit_id = payload.get("id")
            if habit_id:
                for item in habits:
                    if item["id"] == habit_id:
                        item["name"] = payload.get("name", item["name"])
                        if "streak" in payload:
                            try:
                                item["streak"] = int(payload["streak"])
                            except (TypeError, ValueError):
                                item["streak"] = item["streak"]
                        item["lastCheck"] = payload.get("lastCheck", item.get("lastCheck"))
                        return jsonify(item), 200
                return jsonify({"error": "habit not found"}), 404

            new_id = habit_seq["value"]
            habit_seq["value"] += 1
            habit = {
                "id": new_id,
                "name": payload.get("name", "").strip() or "New Habit",
                "streak": int(payload.get("streak", 0) or 0),
                "lastCheck": payload.get("lastCheck") or "",
            }
            habits.append(habit)
            return jsonify(habit), 201

    @app.route("/api/habits/<int:habit_id>/check", methods=["POST"])
    def check_habit(habit_id: int) -> Any:
        with lock:
            for habit in habits:
                if habit["id"] == habit_id:
                    habit["streak"] = int(habit.get("streak", 0)) + 1
                    habit["lastCheck"] = iso_now()
                    return jsonify(habit)
        return jsonify({"error": "habit not found"}), 404

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_frontend(path: str) -> Any:
        static_folder = app.static_folder or ""
        full_path = os.path.join(static_folder, path)
        if path and os.path.exists(full_path):
            return send_from_directory(static_folder, path)
        index_path = os.path.join(static_folder, "index.html")
        if os.path.exists(index_path):
            return send_from_directory(static_folder, "index.html")
        return (
            "Frontend bundle not found. Build the Next.js app to generate static assets.",
            503,
        )

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
