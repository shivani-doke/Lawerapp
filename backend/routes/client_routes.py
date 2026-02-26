from flask import Blueprint, request, jsonify
from database import db
from models.client_model import Client

client_bp = Blueprint("client_bp", __name__, url_prefix="/clients")


# GET ALL CLIENTS
@client_bp.route("/", methods=["GET"])
def get_clients():
    clients = Client.query.all()
    return jsonify([c.to_dict() for c in clients])


# ADD CLIENT
@client_bp.route("/", methods=["POST"])
def add_client():
    data = request.json

    new_client = Client(
        name=data["name"],
        email=data["email"],
        phone=data.get("phone"),
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
    client = Client.query.get(id)

    if not client:
        return jsonify({"error": "Client not found"}), 404

    db.session.delete(client)
    db.session.commit()

    return jsonify({"message": "Client deleted"})

# UPDATE CLIENT
@client_bp.route("/<int:id>", methods=["PUT"])
def update_client(id):
    client = Client.query.get(id)

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
    if "case_type" in data:
        client.case_type = data["case_type"]
    if "status" in data:
        client.status = data["status"]
    if "notes" in data:          
        client.notes = data["notes"]

    db.session.commit()

    return jsonify({"message": "Client updated successfully"})
