# backend/routes/email_routes.py

from flask import Blueprint, request, jsonify
from services.email_service import send_email

email_bp = Blueprint("email_bp", __name__)

@email_bp.route("/send-update", methods=["POST"])
def send_update():
    data = request.get_json()

    to_email = data.get("email")
    subject = data.get("subject")
    message = data.get("message")
    client_name = data.get("client_name")  # optional

    if not to_email or not subject or not message:
        return jsonify({"error": "Missing required fields"}), 400

    result = send_email(to_email, subject, message, client_name)

    if result["success"]:
        return jsonify({"message": "Email sent successfully"}), 200
    else:
        return jsonify({"error": result["error"]}), 500