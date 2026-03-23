# backend/routes/document_routes.py

import os
import json
import tempfile
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify, send_from_directory, abort
from werkzeug.utils import secure_filename

from docx import Document as DocxDocument
from docx.shared import Pt
import PyPDF2

from services.gemini_service import extract_fields_from_document, fill_document_with_fields, replace_placeholders
from services.document_service import GENERATED_FOLDER, PREVIEW_FOLDER, convert_docx_to_pdf

# Folder where template DOCX files are stored
TEMPLATES_FOLDER = "templates"
os.makedirs(TEMPLATES_FOLDER, exist_ok=True)

# Folder for uploaded reference documents
UPLOADS_FOLDER = "uploads"
os.makedirs(UPLOADS_FOLDER, exist_ok=True)
METADATA_FILE = os.path.join(UPLOADS_FOLDER, "metadata.json")

document_bp = Blueprint("document_bp", __name__)

# -------------------------------------------------------------------
# Helper functions for metadata
# -------------------------------------------------------------------
def load_metadata():
    if os.path.exists(METADATA_FILE):
        with open(METADATA_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_metadata(metadata):
    with open(METADATA_FILE, 'w') as f:
        json.dump(metadata, f, indent=2)

def extract_text_from_file(filepath, ext):
    """Extract text from a file based on its extension."""
    try:
        if ext == ".txt":
            with open(filepath, "r", encoding="utf-8") as f:
                return f.read()
        elif ext == ".docx":
            doc = DocxDocument(filepath)
            return "\n".join([para.text for para in doc.paragraphs])
        elif ext == ".pdf":
            with open(filepath, "rb") as f:
                pdf_reader = PyPDF2.PdfReader(f)
                return "\n".join([page.extract_text() for page in pdf_reader.pages])
        else:
            return None
    except Exception as e:
        print(f"Text extraction error: {e}")
        return None

# -------------------------------------------------------------------
# Existing endpoint: extract_fields (unchanged)
# -------------------------------------------------------------------
@document_bp.route("/extract_fields", methods=["POST"])
def extract_fields():
    """Extract fields from uploaded reference document using Gemini."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty file"}), 400

    doc_type = request.form.get("document_type", "power_of_attorney")
    ext = os.path.splitext(file.filename)[1].lower()
    text = ""

    try:
        if ext == ".txt":
            text = file.read().decode("utf-8")
        elif ext == ".docx":
            with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
                file.save(tmp.name)
                tmp_path = tmp.name
            try:
                doc = DocxDocument(tmp_path)
                text = "\n".join([para.text for para in doc.paragraphs])
            finally:
                os.unlink(tmp_path)
        elif ext == ".pdf":
            pdf_reader = PyPDF2.PdfReader(file)
            text = "\n".join([page.extract_text() for page in pdf_reader.pages])
        else:
            return jsonify({"error": f"Unsupported file type: {ext}"}), 400
    except Exception as e:
        return jsonify({"error": f"Could not read file: {str(e)}"}), 400

    fields = extract_fields_from_document(text, doc_type)
    return jsonify(fields)

# -------------------------------------------------------------------
# New endpoint: upload_reference
# -------------------------------------------------------------------
@document_bp.route("/upload_reference", methods=["POST"])
def upload_reference():
    """Upload a reference document, extract fields, save file and metadata."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty file"}), 400

    doc_type = request.form.get("document_type", "power_of_attorney")
    ext = os.path.splitext(file.filename)[1].lower()

    # Generate unique ID and save file
    doc_id = str(uuid.uuid4())
    filename = f"{doc_id}{ext}"
    filepath = os.path.join(UPLOADS_FOLDER, filename)
    file.save(filepath)

    # Extract text for field extraction
    text = extract_text_from_file(filepath, ext)
    if text is None:
        os.unlink(filepath)
        return jsonify({"error": "Could not extract text from file"}), 400

    # Extract fields using Gemini
    fields = extract_fields_from_document(text, doc_type)

    # Save metadata
    metadata = load_metadata()
    metadata[doc_id] = {
        "original_name": file.filename,
        "filename": filename,
        "document_type": doc_type,
        "fields": fields,
        "timestamp": datetime.now().isoformat()
    }
    save_metadata(metadata)

    return jsonify({"document_id": doc_id, "fields": fields})

# -------------------------------------------------------------------
# New endpoint: list_references
# -------------------------------------------------------------------
@document_bp.route("/list_references", methods=["GET"])
def list_references():
    """Return list of saved reference documents, optionally filtered by document_type."""
    doc_type_filter = request.args.get("document_type")
    metadata = load_metadata()
    result = []
    for doc_id, info in metadata.items():
        if doc_type_filter and info.get("document_type") != doc_type_filter:
            continue
        result.append({
            "id": doc_id,
            "original_name": info["original_name"],
            "document_type": info["document_type"],
            "timestamp": info["timestamp"]
        })
    return jsonify(result)

# -------------------------------------------------------------------
# New endpoint: get_reference/<doc_id>
# -------------------------------------------------------------------
@document_bp.route("/get_reference/<doc_id>", methods=["GET"])
def get_reference(doc_id):
    """Return fields for a saved reference document."""
    metadata = load_metadata()
    info = metadata.get(doc_id)
    if not info:
        return jsonify({"error": "Document not found"}), 404
    return jsonify(info["fields"])

# -------------------------------------------------------------------
# NEW endpoint: preview reference document
# -------------------------------------------------------------------
from flask import make_response
@document_bp.route("/references/<doc_id>/view", methods=["GET"])
def view_reference(doc_id):
    metadata = load_metadata()
    info = metadata.get(doc_id)
    if not info:
        abort(404, description="Document not found")

    filename = info["filename"]
    filepath = os.path.join(UPLOADS_FOLDER, filename)

    if not os.path.exists(filepath):
        abort(404, description="File not found")

    ext = os.path.splitext(filename)[1].lower()

    # ✅ If DOCX → convert to PDF for preview
    if ext == ".docx":
        try:
            pdf_filename = filename.replace(".docx", ".pdf")
            pdf_path = os.path.join(PREVIEW_FOLDER, pdf_filename)

            # ✅ CACHE: don't reconvert if already exists
            if not os.path.exists(pdf_path):
                pdf_path = convert_docx_to_pdf(filepath, PREVIEW_FOLDER)
            return send_from_directory(
                PREVIEW_FOLDER,
                os.path.basename(pdf_path),
                mimetype="application/pdf",
                as_attachment=False
            )
        except Exception as e:
            return jsonify({"error": f"Conversion failed: {str(e)}"}), 500

    # ✅ If already PDF → show directly
    elif ext == ".pdf":
        return send_from_directory(
            UPLOADS_FOLDER,
            filename,
            mimetype="application/pdf",
            as_attachment=False
        )

    # ✅ TXT → show inline
    elif ext == ".txt":
        return send_from_directory(
            UPLOADS_FOLDER,
            filename,
            mimetype="text/plain",
            as_attachment=False
        )

    else:
        abort(400, description="Unsupported file type")
# -------------------------------------------------------------------
# Modified endpoint: generate-document (now accepts format parameter)
# -------------------------------------------------------------------
@document_bp.route("/generate-document", methods=["POST"])
def generate_document():
    """
    Generate a final document using either:
      - a newly uploaded reference file, or
      - a previously saved reference document (by reference_id).
    Accepts optional 'format' field: 'table' (use document-specific table template) or 'blank' (use blank template).
    """
    document_type = request.form.get("document_type")
    fields_json = request.form.get("fields", "{}")
    # Read format parameter (default to 'table' for backward compatibility)
    format_type = request.form.get("format", "table")  # 'table' or 'blank'

    try:
        fields = json.loads(fields_json)
    except:
        return jsonify({"error": "Invalid fields JSON"}), 400

    reference_id = request.form.get("reference_id")
    reference_text = ""

    # Determine source of reference text
    if reference_id:
        # Use stored reference
        metadata = load_metadata()
        info = metadata.get(reference_id)
        if not info:
            return jsonify({"error": "Reference document not found"}), 400
        filepath = os.path.join(UPLOADS_FOLDER, info["filename"])
        ext = os.path.splitext(info["filename"])[1].lower()
        reference_text = extract_text_from_file(filepath, ext)
        if reference_text is None:
            return jsonify({"error": "Could not read stored reference file"}), 500
    else:
        # Use uploaded file
        if "reference_file" not in request.files:
            return jsonify({"error": "Reference file required"}), 400
        file = request.files["reference_file"]
        if file.filename == "":
            return jsonify({"error": "Empty file"}), 400
        ext = os.path.splitext(file.filename)[1].lower()
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
            file.save(tmp.name)
            tmp_path = tmp.name
        try:
            if ext == ".txt":
                with open(tmp_path, "r", encoding="utf-8") as f:
                    reference_text = f.read()
            elif ext == ".docx":
                doc = DocxDocument(tmp_path)
                reference_text = "\n".join([para.text for para in doc.paragraphs])
            elif ext == ".pdf":
                with open(tmp_path, "rb") as f:
                    pdf_reader = PyPDF2.PdfReader(f)
                    reference_text = "\n".join([page.extract_text() for page in pdf_reader.pages])
            else:
                return jsonify({"error": f"Unsupported file type: {ext}"}), 400
        except Exception as e:
            os.unlink(tmp_path)
            return jsonify({"error": f"Could not read reference file: {str(e)}"}), 400
        finally:
            os.unlink(tmp_path)

    # Determine which template to use based on format_type
    template_map = {
        "power_of_attorney": "power_of_attorney_template.docx",
        "sale_deed": "sale_deed_template.docx",
        "rental_agreement": "rental_agreement_template.docx",
        "partnership_deed": "partnership_deed_template.docx",
        "affidavit": "affidavit_template.docx",
        "will_testament": "will_testament_template.docx",
        "bail_application": "bail_application_template.docx",
        "loan_agreement": "loan_agreement_template.docx",
    }

    blank_template = "blank_template.docx"
    template_path = None

    if format_type == "blank":
        # Force blank template
        blank_path = os.path.join(TEMPLATES_FOLDER, blank_template)
        if os.path.exists(blank_path):
            template_path = blank_path
        else:
            return jsonify({"error": "Blank template not found on server"}), 500
    else:  # 'table' or any other value -> try to use document-specific table template
        template_filename = template_map.get(document_type)
        if template_filename:
            candidate_path = os.path.join(TEMPLATES_FOLDER, template_filename)
            if os.path.exists(candidate_path):
                template_path = candidate_path
            else:
                print(f"Table template {template_filename} not found. Falling back to blank template.")
                # Fallback to blank template
                blank_path = os.path.join(TEMPLATES_FOLDER, blank_template)
                if os.path.exists(blank_path):
                    template_path = blank_path
                else:
                    return jsonify({"error": f"No table template for '{document_type}' and blank template missing."}), 500
        else:
            # No mapping for this document type – fallback to blank
            blank_path = os.path.join(TEMPLATES_FOLDER, blank_template)
            if os.path.exists(blank_path):
                template_path = blank_path
            else:
                return jsonify({"error": f"No template mapping for '{document_type}' and blank template missing."}), 500

    # Ask Gemini to produce the final document text using the reference document as context
    try:
        final_document_text = fill_document_with_fields(reference_text, fields, document_type)
    except Exception as e:
        return jsonify({"error": f"Document generation failed: {str(e)}"}), 500


    # Create unique output filename with timestamp + incremental counter
    # ----------------------------
    client_name = fields.get("principal", fields.get("client_name", "Client"))
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base_filename = f"{client_name}_{document_type}_{timestamp}_generated"

    # Incremental counter to avoid duplicates
    counter = 1
    output_filename = f"{base_filename}.docx"
    while os.path.exists(os.path.join(GENERATED_FOLDER, output_filename)):
        counter += 1
        output_filename = f"{base_filename}_{counter}.docx"

    output_path = os.path.join(GENERATED_FOLDER, output_filename)
    try:
        # Load the server‑side template (preserves tables, formatting)
        doc = DocxDocument(template_path)
        replace_placeholders(doc, fields)
        # Split Gemini output paragraphs
        gen_paragraphs = final_document_text.split("\n\n")

        # Find first table location
        table_paragraph_index = None
        for i, block in enumerate(doc.element.body):
            if block.tag.endswith('tbl'):
                table_paragraph_index = i
                break

        # Insert text BEFORE the table
        if table_paragraph_index is not None:
            body = doc.element.body
            for text in reversed(gen_paragraphs):
                if text.strip():
                    p = doc.add_paragraph(text.strip())
                    p.runs[0].font.name = "Times New Roman"
                    p.runs[0].font.size = Pt(14)
                    body.insert(table_paragraph_index, p._element)
        else:
            # If no table exists, append normally
            for text in gen_paragraphs:
                if text.strip():
                    p = doc.add_paragraph(text.strip())
                    p.runs[0].font.name = "Times New Roman"
                    p.runs[0].font.size = Pt(14)


        doc.save(output_path)
        pdf_path = convert_docx_to_pdf(output_path, GENERATED_FOLDER)
        pdf_filename = os.path.basename(pdf_path)
    except Exception as e:
        return jsonify({"error": f"Failed to create DOCX: {str(e)}"}), 500

    return jsonify({
        "docx_file": output_filename,
        "pdf_file": pdf_filename
    })

# -------------------------------------------------------------------
# Download and view endpoints (unchanged)
# -------------------------------------------------------------------
@document_bp.route("/download/<filename>", methods=["GET"])
def download_file(filename):
    try:
        as_attachment = request.args.get('download', 'true').lower() != 'false'
        return send_from_directory(
            GENERATED_FOLDER,
            filename,
            as_attachment=True,
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 404

@document_bp.route("/view/<filename>", methods=["GET"])
def view_pdf(filename):
    try:
        response = send_from_directory(
            GENERATED_FOLDER,
            filename,
            mimetype="application/pdf",
            as_attachment=False
        )
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        return response
    except Exception as e:
        return jsonify({"error": str(e)}), 404





















