# backend/routes/dashboard_routes.py

from flask import Blueprint, jsonify, request
from models.client_model import Client
from services.document_service import GENERATED_FOLDER
from database import db
from datetime import datetime
import os

dashboard_bp = Blueprint("dashboard_bp", __name__, url_prefix="/dashboard")


@dashboard_bp.route("/stats", methods=["GET"])
def get_dashboard_stats():
    # Clients count
    clients_count = Client.query.count()

    # Documents count (from generated folder)
    documents_folder = GENERATED_FOLDER
    documents_count = len(os.listdir(documents_folder)) if os.path.exists(documents_folder) else 0

    # Active cases (based on status)
    active_cases = Client.query.filter_by(status="Active").count()

    # Chats (dummy for now OR you can store later)
    chats_count = 0  # Replace when chat DB is added


    # Recent documents
    recent_docs = []
    if os.path.exists(documents_folder):

        # Filter only valid files
        files = [f for f in os.listdir(documents_folder) if f.endswith((".pdf", ".docx"))]
        limit = request.args.get("limit", 4)
        files = sorted(
            files,
            key=lambda x: os.path.getctime(os.path.join(documents_folder, x)),
            reverse=True
        )
        # If limit is not 'all', apply slicing
        if limit != "all":
            files = files[:int(limit)]

        for f in files:
            filepath = os.path.join(documents_folder, f)

            name = f

           
            # ✅ Format date properly
            date = datetime.fromtimestamp(
                os.path.getctime(filepath)
            ).strftime("%b %d, %Y")

            recent_docs.append({
                "title": name,
                
                "date": date,
                "filename": f   # 🔥 IMPORTANT (for opening file in frontend)
            })

    return jsonify({
        "stats": {
            "clients": clients_count,
            "documents": documents_count,
            "active_cases": active_cases,
            "chats": chats_count
        },
        "recent_documents": recent_docs
    })

@dashboard_bp.route("/rename", methods=["POST"])
def rename_document():
    data = request.json

    old_name = data.get("old_name")
    new_name = data.get("new_name")

    if not old_name or not new_name:
        return jsonify({"error": "Missing fields"}), 400

    old_path = os.path.join(GENERATED_FOLDER, old_name)

    # Keep same extension
    ext = os.path.splitext(old_name)[1]
    new_filename = new_name + ext
    new_path = os.path.join(GENERATED_FOLDER, new_filename)

    if not os.path.exists(old_path):
        return jsonify({"error": "File not found"}), 404

    if os.path.exists(new_path):
        return jsonify({"error": "File with this name already exists"}), 400

    os.rename(old_path, new_path)

    return jsonify({
        "message": "Renamed successfully",
        "new_filename": new_filename
    })

@dashboard_bp.route("/delete", methods=["POST"])
def delete_document():
    data = request.get_json()
    filename = data.get("filename")

    file_path = os.path.join(GENERATED_FOLDER, filename)

    if os.path.exists(file_path):
        os.remove(file_path)
        return jsonify({"message": "Deleted successfully"})
    else:
        return jsonify({"error": "File not found"}), 404


from flask import send_from_directory
@dashboard_bp.route("/download/<filename>", methods=["GET"])
def download_document(filename):
    try:
        return send_from_directory(
            GENERATED_FOLDER,
            filename,
            as_attachment=True,   # 🔥 Forces download
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 404