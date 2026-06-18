# backend/routes/email_routes.py
from flask import Blueprint, request, jsonify
from models.firm_model import Firm
from services.auth_context import get_current_user
from services.gmail_service import send_gmail_update

email_bp = Blueprint("email_bp", __name__)

@email_bp.route("/send-update", methods=["POST"])
def send_update():
    data = request.get_json(silent=True) or {}
    current_user = get_current_user(default=None)
    if not current_user:
        return jsonify({"error": "Authentication required"}), 401
    if current_user.is_platform_admin:
        return jsonify({"error": "Use a firm workspace to send client updates"}), 403

    to_email = data.get("email")
    subject = data.get("subject")
    message = data.get("message")
    client_name = data.get("client_name")  # optional

    if not to_email or not subject or not message:
        return jsonify({"error": "Missing required fields"}), 400

    firm = Firm.query.filter_by(id=current_user.firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404
    if not firm.gmail_refresh_token or not firm.gmail_sender_email:
        return jsonify({
            "error": "No firm Gmail mailbox is connected. Ask the firm admin to connect Gmail in Settings.",
        }), 400

    try:
        send_gmail_update(firm, to_email, subject, message, client_name)
        return jsonify({"message": "Email sent successfully"}), 200
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
