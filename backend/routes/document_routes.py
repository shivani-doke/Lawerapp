# backend/routes/document_routes.py

import os
import json
import tempfile
from flask import Blueprint, request, jsonify, send_from_directory

from docx import Document as DocxDocument
from docx.shared import Pt  # <-- added for font size
import PyPDF2

from services.gemini_service import extract_fields_from_document, fill_document_with_fields
from services.document_service import GENERATED_FOLDER, convert_docx_to_pdf
from services.gemini_service import replace_placeholders

# Folder where template DOCX files are stored
TEMPLATES_FOLDER = "templates"
os.makedirs(TEMPLATES_FOLDER, exist_ok=True)

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
                # Extract text from all paragraphs (including those in tables)
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
    Generate a final document using the uploaded reference file as the source for Gemini,
    but using a server‑side template for the final DOCX structure (preserving tables).
    """
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

    ext = os.path.splitext(file.filename)[1].lower()
    reference_text = ""

    # Save uploaded file to a temporary location for text extraction
    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    try:
        if ext == ".txt":
            with open(tmp_path, "r", encoding="utf-8") as f:
                reference_text = f.read()
        elif ext == ".docx":
            doc = DocxDocument(tmp_path)
            # Extract text from all paragraphs (including those in tables)
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

    # Map document type to template filename
    template_map = {
        "power_of_attorney": "power_of_attorney_template.docx"
    }
    template_filename = template_map.get(document_type)
    if not template_filename:
        os.unlink(tmp_path)
        return jsonify({"error": f"No template found for document type: {document_type}"}), 400

    template_path = os.path.join(TEMPLATES_FOLDER, template_filename)
    if not os.path.exists(template_path):
        os.unlink(tmp_path)
        return jsonify({"error": f"Template file missing: {template_filename}"}), 500

    # Ask Gemini to produce the final document text using the reference document as context
    try:
        final_document_text = fill_document_with_fields(reference_text, fields, document_type)
    except Exception as e:
        os.unlink(tmp_path)
        return jsonify({"error": f"Document generation failed: {str(e)}"}), 500

    # Create output filename and path
    client_name = fields.get("principal", fields.get("client_name", "Client"))
    output_filename = f"{client_name}_generated.docx"
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
        pdf_path = convert_docx_to_pdf(output_path)

        pdf_filename = os.path.basename(pdf_path)
    except Exception as e:
        os.unlink(tmp_path)
        return jsonify({"error": f"Failed to create DOCX: {str(e)}"}), 500

    # Clean up temporary uploaded file
    os.unlink(tmp_path)

    return jsonify({
        "docx_file": output_filename,
        "pdf_file": pdf_filename
     })

@document_bp.route("/download/<filename>", methods=["GET"])
def download_file(filename):
    """Download or view a generated document."""
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

        # Add CORS headers for Flutter Web
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"

        return response

    except Exception as e:
        return jsonify({"error": str(e)}), 404



# # backend/routes/document_routes.py
# import os
# import json
# import tempfile
# import PyPDF2
# from docx import Document as DocxDocument
# from flask import Blueprint, request, jsonify, send_from_directory

# from services.gemini_service import extract_fields_from_document, fill_document_with_fields
# from services.document_service import save_uploaded_file, GENERATED_FOLDER

# document_bp = Blueprint("document_bp", __name__)

# @document_bp.route("/extract_fields", methods=["POST"])
# def extract_fields():
#     """Extract fields from uploaded reference document using Gemini."""
#     if "file" not in request.files:
#         return jsonify({"error": "No file provided"}), 400

#     file = request.files["file"]
#     if file.filename == "":
#         return jsonify({"error": "Empty file"}), 400

#     doc_type = request.form.get("document_type", "power_of_attorney")
#     ext = os.path.splitext(file.filename)[1].lower()
#     text = ""

#     try:
#         if ext == ".txt":
#             text = file.read().decode("utf-8")
#         elif ext == ".docx":
#             with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
#                 file.save(tmp.name)
#                 tmp_path = tmp.name
#             try:
#                 doc = DocxDocument(tmp_path)
#                 text = "\n".join([para.text for para in doc.paragraphs])
#             finally:
#                 os.unlink(tmp_path)
#         elif ext == ".pdf":
#             pdf_reader = PyPDF2.PdfReader(file)
#             text = "\n".join([page.extract_text() for page in pdf_reader.pages])
#         else:
#             return jsonify({"error": f"Unsupported file type: {ext}"}), 400
#     except Exception as e:
#         return jsonify({"error": f"Could not read file: {str(e)}"}), 400

#     fields = extract_fields_from_document(text, doc_type)
#     return jsonify(fields)

# @document_bp.route("/generate-document", methods=["POST"])
# def generate_document():
#     """
#     Generate a final document by asking Gemini to insert the provided field values
#     into the reference document. The reference file is required again.
#     """
#     # Get form data
#     document_type = request.form.get("document_type")
#     fields_json = request.form.get("fields", "{}")
#     try:
#         fields = json.loads(fields_json)
#     except:
#         return jsonify({"error": "Invalid fields JSON"}), 400

#     if "reference_file" not in request.files:
#         return jsonify({"error": "Reference file required"}), 400

#     file = request.files["reference_file"]
#     if file.filename == "":
#         return jsonify({"error": "Empty file"}), 400

#     # Extract text from the reference file (support .txt, .docx, .pdf)
#     ext = os.path.splitext(file.filename)[1].lower()
#     reference_text = ""

#     try:
#         if ext == ".txt":
#             reference_text = file.read().decode("utf-8")
#         elif ext == ".docx":
#             with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
#                 file.save(tmp.name)
#                 tmp_path = tmp.name
#             try:
#                 doc = DocxDocument(tmp_path)
#                 reference_text = "\n".join([para.text for para in doc.paragraphs])
#             finally:
#                 os.unlink(tmp_path)
#         elif ext == ".pdf":
#             pdf_reader = PyPDF2.PdfReader(file)
#             reference_text = "\n".join([page.extract_text() for page in pdf_reader.pages])
#         else:
#             return jsonify({"error": f"Unsupported file type: {ext}"}), 400
#     except Exception as e:
#         return jsonify({"error": f"Could not read reference file: {str(e)}"}), 400

#     # Ask Gemini to produce the final document text
#     try:
#         final_document_text = fill_document_with_fields(reference_text, fields, document_type)
#     except Exception as e:
#         return jsonify({"error": f"Document generation failed: {str(e)}"}), 500

#     # Create a DOCX from the generated text
#     client_name = fields.get("principal", fields.get("client_name", "Client"))
#     output_filename = f"{client_name}_generated.docx"
#     output_path = os.path.join(GENERATED_FOLDER, output_filename)

#     try:
#         doc = DocxDocument()
#         # Split by double newline to preserve paragraphs
#         paragraphs = final_document_text.split('\n\n')
#         for para in paragraphs:
#             if para.strip():
#                 doc.add_paragraph(para.strip())
#         doc.save(output_path)
#     except Exception as e:
#         return jsonify({"error": f"Failed to create DOCX: {str(e)}"}), 500

# @document_bp.route("/document-content/<filename>", methods=["GET"])
# def get_document_content(filename):
#     """Return the content of a generated document as plain text."""
#     file_path = os.path.join(GENERATED_FOLDER, filename)
#     if not os.path.exists(file_path):
#         return jsonify({"error": "File not found"}), 404

#     try:
#         doc = DocxDocument(file_path)
#         # Extract text from all paragraphs
#         text = "\n".join([para.text for para in doc.paragraphs])
#         return jsonify({"content": text})
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# @document_bp.route("/update-document/<filename>", methods=["POST"])
# def update_document(filename):
#     """Update the generated document with new text content."""
#     data = request.get_json()
#     if not data or "content" not in data:
#         return jsonify({"error": "No content provided"}), 400

#     file_path = os.path.join(GENERATED_FOLDER, filename)
#     if not os.path.exists(file_path):
#         return jsonify({"error": "File not found"}), 404

#     try:
#         # Create a new DOCX from the provided text
#         doc = DocxDocument()
#         # Split content into paragraphs (by double newline) to preserve basic structure
#         paragraphs = data["content"].split('\n\n')
#         for para in paragraphs:
#             if para.strip():
#                 doc.add_paragraph(para.strip())
#         doc.save(file_path)
#         return jsonify({"message": "Document updated successfully"})
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500