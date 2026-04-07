# backend/routes/dashboard_routes.py

from flask import Blueprint, jsonify, request
from models.client_model import Client
from models.payment_model import Payment
from services.document_service import GENERATED_DOCS_FOLDER, GENERATED_FOLDER
from database import db
from datetime import datetime
import os
import json
from services.auth_context import get_request_username

dashboard_bp = Blueprint("dashboard_bp", __name__, url_prefix="/dashboard")
GENERATED_METADATA_FILE = os.path.join(GENERATED_FOLDER, "generated_metadata.json")


def load_generated_metadata():
    if os.path.exists(GENERATED_METADATA_FILE):
        with open(GENERATED_METADATA_FILE, "r") as f:
            return json.load(f)
    return {}


def save_generated_metadata(metadata):
    with open(GENERATED_METADATA_FILE, "w") as f:
        json.dump(metadata, f, indent=2)


def ensure_generated_metadata_defaults():
    metadata = load_generated_metadata()
    changed = False

    for folder in (GENERATED_FOLDER, GENERATED_DOCS_FOLDER):
        if not os.path.exists(folder):
            continue
        for filename in os.listdir(folder):
            full_path = os.path.join(folder, filename)
            if not os.path.isfile(full_path):
                continue
            if filename not in metadata:
                metadata[filename] = {
                    "owner_username": "admin",
                    "timestamp": datetime.fromtimestamp(
                        os.path.getctime(full_path)
                    ).isoformat(),
                }
                changed = True
            elif not metadata[filename].get("owner_username"):
                metadata[filename]["owner_username"] = "admin"
                changed = True

    if changed:
        save_generated_metadata(metadata)


def get_matching_docx_name(pdf_filename):
    stem, ext = os.path.splitext(pdf_filename)
    if ext.lower() != ".pdf":
        return None
    return f"{stem}.docx"


@dashboard_bp.route("/stats", methods=["GET"])
def get_dashboard_stats():
    username = get_request_username()
    # Clients count
    clients_count = Client.query.filter_by(owner_username=username).count()

    # Documents count (from generated folder)
    ensure_generated_metadata_defaults()
    generated_metadata = load_generated_metadata()
    documents_folder = GENERATED_FOLDER
    documents_count = 0
    if os.path.exists(documents_folder):
        documents_count = len([
            f for f in os.listdir(documents_folder)
            if f.lower().endswith(".pdf")
            and (generated_metadata.get(f, {}).get("owner_username") or "admin") == username
        ])

    # Active cases (based on status)
    active_cases = Client.query.filter_by(
        status="Active",
        owner_username=username,
    ).count()

    total_received = db.session.query(db.func.coalesce(db.func.sum(Payment.amount), 0.0)).filter(
        Payment.owner_username == username
    ).scalar() or 0.0

    # Chats (dummy for now OR you can store later)
    chats_count = 0  # Replace when chat DB is added


    # Recent documents
    recent_docs = []
    if os.path.exists(documents_folder):

        # Filter only valid files
        files = [
            f for f in os.listdir(documents_folder)
            if f.lower().endswith(".pdf")
            and (generated_metadata.get(f, {}).get("owner_username") or "admin") == username
        ]
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
            "chats": chats_count,
            "total_received": float(total_received),
        },
        "recent_documents": recent_docs
    })

@dashboard_bp.route("/rename", methods=["POST"])
def rename_document():
    data = request.json
    username = get_request_username()

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

    ensure_generated_metadata_defaults()
    metadata = load_generated_metadata()
    info = metadata.get(old_name)
    if not info or (info.get("owner_username") or "admin") != username:
        return jsonify({"error": "File not found"}), 404

    if os.path.exists(new_path):
        return jsonify({"error": "File with this name already exists"}), 400

    old_docx_name = get_matching_docx_name(old_name)
    new_docx_name = get_matching_docx_name(new_filename)
    if old_docx_name and new_docx_name:
        old_docx_path = os.path.join(GENERATED_DOCS_FOLDER, old_docx_name)
        new_docx_path = os.path.join(GENERATED_DOCS_FOLDER, new_docx_name)
        if os.path.exists(old_docx_path):
            if os.path.exists(new_docx_path):
                return jsonify({"error": "Matching DOCX file with this name already exists"}), 400

    os.rename(old_path, new_path)
    metadata[new_filename] = metadata.pop(old_name)

    if old_docx_name and new_docx_name:
        old_docx_path = os.path.join(GENERATED_DOCS_FOLDER, old_docx_name)
        new_docx_path = os.path.join(GENERATED_DOCS_FOLDER, new_docx_name)
        if os.path.exists(old_docx_path):
            os.rename(old_docx_path, new_docx_path)
            if old_docx_name in metadata:
                metadata[new_docx_name] = metadata.pop(old_docx_name)

    save_generated_metadata(metadata)

    return jsonify({
        "message": "Renamed successfully",
        "new_filename": new_filename
    })

@dashboard_bp.route("/delete", methods=["POST"])
def delete_document():
    data = request.get_json()
    filename = data.get("filename")
    username = get_request_username()

    file_path = os.path.join(GENERATED_FOLDER, filename)
    ensure_generated_metadata_defaults()
    metadata = load_generated_metadata()
    info = metadata.get(filename)
    if not info or (info.get("owner_username") or "admin") != username:
        return jsonify({"error": "File not found"}), 404

    if os.path.exists(file_path):
        os.remove(file_path)
        metadata.pop(filename, None)

        docx_name = get_matching_docx_name(filename)
        if docx_name:
            docx_path = os.path.join(GENERATED_DOCS_FOLDER, docx_name)
            if os.path.exists(docx_path):
                os.remove(docx_path)
            metadata.pop(docx_name, None)
        save_generated_metadata(metadata)
        return jsonify({"message": "Deleted successfully"})
    else:
        return jsonify({"error": "File not found"}), 404


from flask import send_from_directory
@dashboard_bp.route("/download/<filename>", methods=["GET"])
def download_document(filename):
    try:
        username = get_request_username()
        ensure_generated_metadata_defaults()
        metadata = load_generated_metadata()
        info = metadata.get(filename)
        if not info or (info.get("owner_username") or "admin") != username:
            return jsonify({"error": "File not found"}), 404
        return send_from_directory(
            GENERATED_FOLDER,
            filename,
            as_attachment=True,   # 🔥 Forces download
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 404
