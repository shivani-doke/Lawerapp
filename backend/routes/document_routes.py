# backend/routes/document_routes.py
import os
import json
import tempfile
import PyPDF2
from docx import Document as DocxDocument
from flask import Blueprint, request, jsonify, send_from_directory

from services.gemini_service import extract_fields_from_document, fill_document_with_fields
from services.document_service import save_uploaded_file, GENERATED_FOLDER

document_bp = Blueprint("document_bp", __name__)

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

@document_bp.route("/generate-document", methods=["POST"])
def generate_document():
    """
    Generate a final document by asking Gemini to insert the provided field values
    into the reference document. The reference file is required again.
    """
    # Get form data
    document_type = request.form.get("document_type")
    fields_json = request.form.get("fields", "{}")
    try:
        fields = json.loads(fields_json)
    except:
        return jsonify({"error": "Invalid fields JSON"}), 400

    if "reference_file" not in request.files:
        return jsonify({"error": "Reference file required"}), 400

    file = request.files["reference_file"]
    if file.filename == "":
        return jsonify({"error": "Empty file"}), 400

    # Extract text from the reference file (support .txt, .docx, .pdf)
    ext = os.path.splitext(file.filename)[1].lower()
    reference_text = ""

    try:
        if ext == ".txt":
            reference_text = file.read().decode("utf-8")
        elif ext == ".docx":
            with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
                file.save(tmp.name)
                tmp_path = tmp.name
            try:
                doc = DocxDocument(tmp_path)
                reference_text = "\n".join([para.text for para in doc.paragraphs])
            finally:
                os.unlink(tmp_path)
        elif ext == ".pdf":
            pdf_reader = PyPDF2.PdfReader(file)
            reference_text = "\n".join([page.extract_text() for page in pdf_reader.pages])
        else:
            return jsonify({"error": f"Unsupported file type: {ext}"}), 400
    except Exception as e:
        return jsonify({"error": f"Could not read reference file: {str(e)}"}), 400

    # Ask Gemini to produce the final document text
    try:
        final_document_text = fill_document_with_fields(reference_text, fields, document_type)
    except Exception as e:
        return jsonify({"error": f"Document generation failed: {str(e)}"}), 500

    # Create a DOCX from the generated text
    client_name = fields.get("principal", fields.get("client_name", "Client"))
    output_filename = f"{client_name}_generated.docx"
    output_path = os.path.join(GENERATED_FOLDER, output_filename)

    try:
        doc = DocxDocument()
        # Split by double newline to preserve paragraphs
        paragraphs = final_document_text.split('\n\n')
        for para in paragraphs:
            if para.strip():
                doc.add_paragraph(para.strip())
        doc.save(output_path)
    except Exception as e:
        return jsonify({"error": f"Failed to create DOCX: {str(e)}"}), 500

    return jsonify({
        "message": "Document generated successfully",
        "file_path": output_filename
    })

@document_bp.route("/download/<filename>")
def download_file(filename):
    """Serve a generated document for download."""
    return send_from_directory(GENERATED_FOLDER, filename, as_attachment=True)

@document_bp.route("/document-content/<filename>", methods=["GET"])
def get_document_content(filename):
    """Return the content of a generated document as plain text."""
    file_path = os.path.join(GENERATED_FOLDER, filename)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found"}), 404

    try:
        doc = DocxDocument(file_path)
        # Extract text from all paragraphs
        text = "\n".join([para.text for para in doc.paragraphs])
        return jsonify({"content": text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@document_bp.route("/update-document/<filename>", methods=["POST"])
def update_document(filename):
    """Update the generated document with new text content."""
    data = request.get_json()
    if not data or "content" not in data:
        return jsonify({"error": "No content provided"}), 400

    file_path = os.path.join(GENERATED_FOLDER, filename)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found"}), 404

    try:
        # Create a new DOCX from the provided text
        doc = DocxDocument()
        # Split content into paragraphs (by double newline) to preserve basic structure
        paragraphs = data["content"].split('\n\n')
        for para in paragraphs:
            if para.strip():
                doc.add_paragraph(para.strip())
        doc.save(file_path)
        return jsonify({"message": "Document updated successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500