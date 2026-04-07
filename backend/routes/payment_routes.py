from flask import Blueprint, jsonify, request

from database import db
from models.client_model import Client
from models.payment_model import Payment
from services.auth_context import get_request_username

payment_bp = Blueprint("payment_bp", __name__, url_prefix="/payments")


def _serialize_client_finance(client, payments):
    total_fee = float(client.fee_amount or 0.0)
    total_received = float(sum(float(payment.amount or 0.0) for payment in payments))
    pending_amount = max(total_fee - total_received, 0.0)

    return {
        "client": client.to_dict(),
        "summary": {
            "total_fee": total_fee,
            "total_received": total_received,
            "pending_amount": pending_amount,
            "payment_count": len(payments),
        },
        "payments": [payment.to_dict() for payment in payments],
    }


@payment_bp.route("/client/<int:client_id>", methods=["GET"])
def get_client_payments(client_id):
    username = get_request_username()
    client = Client.query.filter_by(id=client_id, owner_username=username).first()

    if not client:
        return jsonify({"error": "Client not found"}), 404

    payments = Payment.query.filter_by(
        client_id=client_id,
        owner_username=username,
    ).order_by(Payment.payment_date.desc(), Payment.id.desc()).all()

    return jsonify(_serialize_client_finance(client, payments))


@payment_bp.route("/", methods=["POST"])
def add_payment():
    username = get_request_username()
    data = request.get_json() or {}

    client_id = data.get("client_id")
    amount = data.get("amount")
    payment_date = (data.get("payment_date") or "").strip()

    if not client_id or amount in (None, "") or not payment_date:
        return jsonify({"error": "Client, amount, and payment date are required"}), 400

    try:
        client_id = int(client_id)
        amount = float(amount)
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid payment data"}), 400

    if amount <= 0:
        return jsonify({"error": "Payment amount must be greater than zero"}), 400

    client = Client.query.filter_by(id=client_id, owner_username=username).first()
    if not client:
        return jsonify({"error": "Client not found"}), 404

    payment = Payment(
        client_id=client_id,
        owner_username=username,
        amount=amount,
        payment_mode=(data.get("payment_mode") or "").strip() or None,
        payment_date=payment_date,
        notes=(data.get("notes") or "").strip() or None,
    )
    db.session.add(payment)
    db.session.commit()

    return jsonify({
        "message": "Payment added successfully",
        "payment": payment.to_dict(),
    }), 201


@payment_bp.route("/<int:payment_id>", methods=["DELETE"])
def delete_payment(payment_id):
    username = get_request_username()
    payment = Payment.query.filter_by(id=payment_id, owner_username=username).first()

    if not payment:
        return jsonify({"error": "Payment not found"}), 404

    db.session.delete(payment)
    db.session.commit()

    return jsonify({"message": "Payment deleted successfully"})


@payment_bp.route("/report", methods=["GET"])
def get_payment_report():
    username = get_request_username()
    clients = Client.query.filter_by(owner_username=username).order_by(Client.name.asc()).all()
    client_ids = [client.id for client in clients]

    payments = []
    if client_ids:
        payments = Payment.query.filter(
            Payment.owner_username == username,
            Payment.client_id.in_(client_ids),
        ).order_by(Payment.payment_date.desc(), Payment.id.desc()).all()

    payments_by_client = {}
    for payment in payments:
        payments_by_client.setdefault(payment.client_id, []).append(payment)

    client_reports = []
    total_fee = 0.0
    total_received = 0.0

    for client in clients:
        client_payments = payments_by_client.get(client.id, [])
        summary = _serialize_client_finance(client, client_payments)["summary"]
        total_fee += summary["total_fee"]
        total_received += summary["total_received"]
        client_reports.append({
            "client_id": client.id,
            "client_name": client.name,
            "case_type": client.case_type,
            "status": client.status,
            "fee_amount": summary["total_fee"],
            "total_received": summary["total_received"],
            "pending_amount": summary["pending_amount"],
            "payment_count": summary["payment_count"],
        })

    pending_amount = max(total_fee - total_received, 0.0)
    clients_with_pending = len([
        report for report in client_reports if float(report["pending_amount"]) > 0
    ])

    return jsonify({
        "summary": {
            "total_fee": total_fee,
            "total_received": total_received,
            "pending_amount": pending_amount,
            "clients_with_pending": clients_with_pending,
            "total_clients": len(clients),
            "total_payments": len(payments),
        },
        "client_reports": client_reports,
        "recent_payments": [payment.to_dict() for payment in payments[:10]],
    })
