# backend/routes/client_routes.py

from flask import Blueprint, request, jsonify
from database import db
from models.client_model import Client
from models.payment_model import Payment
from services.auth_context import get_current_user

client_bp = Blueprint("client_bp", __name__, url_prefix="/clients")


def require_authenticated_user():
    user = get_current_user(default=None)
    if user is None:
        return None, (jsonify({"error": "Authentication required"}), 401)
    return user, None


# GET ALL CLIENTS
@client_bp.route("/", methods=["GET"])
def get_clients():
    user, error_response = require_authenticated_user()
    if error_response:
        return error_response
    clients = Client.query.filter_by(firm_id=user.firm_id).all()
    return jsonify([c.to_dict() for c in clients])


# ADD CLIENT
@client_bp.route("/", methods=["POST"])
def add_client():
    data = request.json
    user, error_response = require_authenticated_user()
    if error_response:
        return error_response
    fee_amount = data.get("fee_amount") or 0
    if not user.can_manage_billing:
        fee_amount = 0

    new_client = Client(
        owner_username=user.username,
        firm_id=user.firm_id,
        firm_name=user.firm_name,
        name=data["name"],
        email=data["email"],
        phone=data.get("phone"),
        age=data.get("age"),
        occupation=data.get("occupation"),
        address=data.get("address"),
        pan_number=data.get("pan_number"),
        aadhar_number=data.get("aadhar_number"),
        fee_amount=fee_amount,
        case_type=data["case_type"],
        status=data["status"],
        notes=data.get("notes")
    )

    db.session.add(new_client)
    db.session.commit()

    return jsonify({"message": "Client added successfully"})


# DELETE CLIENT
@client_bp.route("/<int:id>", methods=["DELETE"])
def delete_client(id):
    user, error_response = require_authenticated_user()
    if error_response:
        return error_response
    client = Client.query.filter_by(id=id, firm_id=user.firm_id).first()

    if not client:
        return jsonify({"error": "Client not found"}), 404

    Payment.query.filter_by(client_id=id, firm_id=user.firm_id).delete()
    db.session.delete(client)
    db.session.commit()

    return jsonify({"message": "Client deleted"})

# UPDATE CLIENT
@client_bp.route("/<int:id>", methods=["PUT"])
def update_client(id):
    user, error_response = require_authenticated_user()
    if error_response:
        return error_response
    client = Client.query.filter_by(id=id, firm_id=user.firm_id).first()

    if not client:
        return jsonify({"error": "Client not found"}), 404

    data = request.json

    # Update fields (only if provided in request)
    if "name" in data:
        client.name = data["name"]
    if "email" in data:
        client.email = data["email"]
    if "phone" in data:
        client.phone = data["phone"]
    if "age" in data:
        client.age = data["age"]
    if "occupation" in data:
        client.occupation = data["occupation"]
    if "address" in data:
        client.address = data["address"]
    if "pan_number" in data:
        client.pan_number = data["pan_number"]
    if "aadhar_number" in data:
        client.aadhar_number = data["aadhar_number"]
    if "fee_amount" in data:
        if user.can_manage_billing:
            client.fee_amount = data["fee_amount"] or 0
    if "case_type" in data:
        client.case_type = data["case_type"]
    if "status" in data:
        client.status = data["status"]
    if "notes" in data:          
        client.notes = data["notes"]

    db.session.commit()

    return jsonify({"message": "Client updated successfully"})
