import os
from datetime import datetime

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
CORS(app)

DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "jobtrackr")

app.config["SQLALCHEMY_DATABASE_URI"] = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

VALID_STATUSES = {"applied", "screening", "interview", "offer", "rejected"}


class Application(db.Model):
    __tablename__ = "applications"

    id = db.Column(db.Integer, primary_key=True)
    company = db.Column(db.String(120), nullable=False)
    role = db.Column(db.String(120), nullable=False)
    status = db.Column(db.String(30), nullable=False, default="applied")
    applied_date = db.Column(db.Date, nullable=False)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "company": self.company,
            "role": self.role,
            "status": self.status,
            "applied_date": self.applied_date.isoformat() if self.applied_date else None,
            "notes": self.notes,
        }


@app.route("/health")
def health():
    # This is what the Azure Load Balancer / App Gateway health probe hits.
    # Keep it dependency-free so a slow DB doesn't take the probe down with it.
    return jsonify(status="ok"), 200


@app.route("/api/applications", methods=["GET"])
def list_applications():
    status_filter = request.args.get("status")
    query = Application.query
    if status_filter:
        query = query.filter_by(status=status_filter)
    applications = query.order_by(Application.applied_date.desc()).all()
    return jsonify([a.to_dict() for a in applications])


@app.route("/api/applications", methods=["POST"])
def create_application():
    data = request.get_json(force=True) or {}
    company = (data.get("company") or "").strip()
    role = (data.get("role") or "").strip()
    status = (data.get("status") or "applied").strip().lower()
    notes = data.get("notes", "")
    applied_date_str = data.get("applied_date")

    if not company or not role:
        return jsonify(error="company and role are required"), 400
    if status not in VALID_STATUSES:
        return jsonify(error=f"status must be one of {sorted(VALID_STATUSES)}"), 400

    try:
        applied_date = (
            datetime.strptime(applied_date_str, "%Y-%m-%d").date()
            if applied_date_str
            else datetime.utcnow().date()
        )
    except ValueError:
        return jsonify(error="applied_date must be in YYYY-MM-DD format"), 400

    application = Application(
        company=company,
        role=role,
        status=status,
        applied_date=applied_date,
        notes=notes,
    )
    db.session.add(application)
    db.session.commit()
    return jsonify(application.to_dict()), 201


@app.route("/api/applications/<int:app_id>", methods=["PUT"])
def update_application(app_id):
    application = Application.query.get_or_404(app_id)
    data = request.get_json(force=True) or {}

    if "status" in data:
        status = (data["status"] or "").strip().lower()
        if status not in VALID_STATUSES:
            return jsonify(error=f"status must be one of {sorted(VALID_STATUSES)}"), 400
        application.status = status
    if "company" in data:
        application.company = data["company"].strip()
    if "role" in data:
        application.role = data["role"].strip()
    if "notes" in data:
        application.notes = data["notes"]
    if "applied_date" in data:
        try:
            application.applied_date = datetime.strptime(data["applied_date"], "%Y-%m-%d").date()
        except ValueError:
            return jsonify(error="applied_date must be in YYYY-MM-DD format"), 400

    db.session.commit()
    return jsonify(application.to_dict())


@app.route("/api/applications/<int:app_id>", methods=["DELETE"])
def delete_application(app_id):
    application = Application.query.get_or_404(app_id)
    db.session.delete(application)
    db.session.commit()
    return "", 204


@app.route("/api/stats", methods=["GET"])
def stats():
    rows = (
        db.session.query(Application.status, db.func.count(Application.id))
        .group_by(Application.status)
        .all()
    )
    counts = {status: count for status, count in rows}
    for s in VALID_STATUSES:
        counts.setdefault(s, 0)
    return jsonify(counts)


@app.route("/api/init-db", methods=["POST"])
def init_db():
    # Convenience endpoint for local/dev use only — creates tables if they don't exist.
    # Don't expose this in production; it's here so you're not fighting migrations
    # while you're still learning the app itself.
    db.create_all()
    return jsonify(status="tables created"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
