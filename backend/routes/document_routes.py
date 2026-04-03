# backend/routes/document_routes.py

import os
import json
import tempfile
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify, send_from_directory, abort
from werkzeug.utils import secure_filename

from docx import Document as DocxDocument
from docx.oxml.ns import qn
from docx.shared import Inches, Mm, Pt
import PyPDF2

from services.gemini_service import (
    SUPPORTED_GENERATION_LANGUAGES,
    fill_document_with_fields,
    generate_document_from_fields_only,
    localize_field_schema,
    localize_field_values,
    replace_placeholders,
)
from services.document_service import (
    GENERATED_DOCS_FOLDER,
    GENERATED_FOLDER,
    PREVIEW_FOLDER,
    convert_docx_to_pdf,
)
from services.document_fields import get_fields_for_document_type, get_subtypes_for_document_type

SUPPORTED_FONT_FAMILIES = (
    "Times New Roman",
    "Arial",
    "Calibri",
    "Cambria",
    "Georgia",
    "Garamond",
    "Verdana",
    "Tahoma",
    "Trebuchet MS",
    "Nirmala UI",
    "Mangal",
)

DEFAULT_FONT_SIZE = 14
MIN_FONT_SIZE = 8
MAX_FONT_SIZE = 28

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

def normalize_document_type(document_type):
    return (document_type or "").strip().lower()

def get_document_title(document_type):
    doc_type = normalize_document_type(document_type)
    title_map = {
        "power_of_attorney": "POWER OF ATTORNEY",
        "gift_deed": "GIFT DEED",
        "rental_agreement": "RENTAL AGREEMENT",
        "partnership_deed": "PARTNERSHIP DEED",
        "affidavit": "AFFIDAVIT",
        "will_and_testament": "WILL AND TESTAMENT",
        "bail_application": "BAIL APPLICATION",
        "loan_agreement": "LOAN AGREEMENT",
        "divorce_paper": "DIVORCE PAPER",
        "sale_deed": "SALE DEED",
        "mortgage_deed": "MORTGAGE DEED",
        "non_disclosure_agreement": "NON-DISCLOSURE AGREEMENT",
        "employment_contract": "EMPLOYMENT CONTRACT",
        "offer_letter": "OFFER LETTER",
        "service_agreement": "SERVICE AGREEMENT",
        "child_custody_agreement": "CHILD CUSTODY AGREEMENT",
        "adoption_papers": "ADOPTION PAPERS",
        "partition_deed": "PARTITION DEED",
        "trust_deed": "TRUST DEED",
        "memorandum_of_understanding": "MEMORANDUM OF UNDERSTANDING",
        "vendor_agreement": "VENDOR AGREEMENT",
        "non_compete_agreement": "NON-COMPETE AGREEMENT",
        "indemnity_agreement": "INDEMNITY AGREEMENT",
        "joint_venture_agreement": "JOINT VENTURE AGREEMENT",
        "licensing_agreement": "LICENSING AGREEMENT",
        "assignment_agreement": "ASSIGNMENT AGREEMENT",
        "settlement_agreement": "SETTLEMENT AGREEMENT",
        "trademark_application": "TRADEMARK APPLICATION",
        "copyright_agreement": "COPYRIGHT AGREEMENT",
        "patent_filing_documents": "PATENT FILING DOCUMENTS",
    }
    if doc_type in title_map:
        return title_map[doc_type]
    return doc_type.replace("_", " ").strip().upper()


def get_generated_file_directory(filename):
    ext = os.path.splitext(filename)[1].lower()
    if ext == ".pdf":
        return GENERATED_FOLDER
    if ext == ".docx":
        return GENERATED_DOCS_FOLDER
    return GENERATED_FOLDER


def normalize_generation_language(language):
    requested = (language or "").strip().lower()
    for supported_language in SUPPORTED_GENERATION_LANGUAGES:
        if requested == supported_language.lower():
            return supported_language
    return SUPPORTED_GENERATION_LANGUAGES[0]


def normalize_font_family(font_family):
    requested = (font_family or "").strip().lower()
    for supported_font_family in SUPPORTED_FONT_FAMILIES:
        if requested == supported_font_family.lower():
            return supported_font_family
    return SUPPORTED_FONT_FAMILIES[0]


def normalize_font_size(font_size):
    try:
        parsed_size = int(str(font_size).strip())
    except (TypeError, ValueError):
        return DEFAULT_FONT_SIZE
    return max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, parsed_size))


def normalize_paper_size(paper_size):
    requested = str(paper_size or "").strip().lower()
    supported_sizes = {
        "a4": "A4",
        "letter": "Letter",
        "legal": "Legal",
    }
    return supported_sizes.get(requested, "A4")


def normalize_line_spacing(line_spacing):
    requested = str(line_spacing or "").strip().lower()
    supported_spacing = {
        "single": 1.0,
        "1": 1.0,
        "1.0": 1.0,
        "1.15": 1.15,
        "1.5": 1.5,
        "double": 2.0,
        "2": 2.0,
        "2.0": 2.0,
    }
    return supported_spacing.get(requested, 1.0)


def normalize_margin_size(margin_size):
    requested = str(margin_size or "").strip().lower()
    supported_margins = {
        "normal": "Normal",
        "narrow": "Narrow",
        "moderate": "Moderate",
        "wide": "Wide",
    }
    return supported_margins.get(requested, "Normal")


def apply_font_to_run(run, font_family, font_size):
    run.font.name = font_family
    run.font.size = Pt(font_size)
    run_properties = run._element.get_or_add_rPr()
    run_properties.rFonts.set(qn("w:ascii"), font_family)
    run_properties.rFonts.set(qn("w:hAnsi"), font_family)
    run_properties.rFonts.set(qn("w:eastAsia"), font_family)
    run_properties.rFonts.set(qn("w:cs"), font_family)


def apply_font_settings(doc, font_family, font_size):
    normal_style = doc.styles["Normal"]
    normal_style.font.name = font_family
    normal_style.font.size = Pt(font_size)
    style_properties = normal_style.element.get_or_add_rPr()
    style_properties.rFonts.set(qn("w:ascii"), font_family)
    style_properties.rFonts.set(qn("w:hAnsi"), font_family)
    style_properties.rFonts.set(qn("w:eastAsia"), font_family)
    style_properties.rFonts.set(qn("w:cs"), font_family)

    for paragraph in doc.paragraphs:
        for run in paragraph.runs:
            apply_font_to_run(run, font_family, font_size)

    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    for run in paragraph.runs:
                        apply_font_to_run(run, font_family, font_size)


def apply_paper_size(doc, paper_size):
    for section in doc.sections:
        if paper_size == "Letter":
            section.page_width = Inches(8.5)
            section.page_height = Inches(11)
        elif paper_size == "Legal":
            section.page_width = Inches(8.5)
            section.page_height = Inches(14)
        else:
            section.page_width = Mm(210)
            section.page_height = Mm(297)


def apply_margin_settings(doc, margin_size):
    margin_map = {
        "Normal": Inches(1.0),
        "Narrow": Inches(0.5),
        "Moderate": Inches(0.75),
        "Wide": Inches(1.5),
    }
    margin_value = margin_map.get(margin_size, margin_map["Normal"])

    for section in doc.sections:
        section.top_margin = margin_value
        section.bottom_margin = margin_value
        section.left_margin = margin_value
        section.right_margin = margin_value


def apply_line_spacing_settings(doc, line_spacing):
    for paragraph in doc.paragraphs:
        paragraph.paragraph_format.line_spacing = line_spacing

    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    paragraph.paragraph_format.line_spacing = line_spacing


def apply_document_layout_settings(doc, paper_size, line_spacing, margin_size):
    apply_paper_size(doc, paper_size)
    apply_margin_settings(doc, margin_size)
    apply_line_spacing_settings(doc, line_spacing)

def enrich_divorce_fields(fields):
    enriched = dict(fields or {})
    divorce_type = str(enriched.get("divorce_type", "")).strip()
    mutual_first_petitioner = str(enriched.get("mutual_first_petitioner", "")).strip()
    contested_filed_by = str(enriched.get("contested_filed_by", "")).strip()

    husband_name = str(enriched.get("husband_name", "")).strip()
    wife_name = str(enriched.get("wife_name", "")).strip()

    if divorce_type == "Mutual Consent":
        first_party = mutual_first_petitioner or "Husband"
        second_party = "Wife" if first_party == "Husband" else "Husband"

        enriched["husband_role_label"] = (
            "Petitioner No. 1" if first_party == "Husband" else "Petitioner No. 2"
        )
        enriched["wife_role_label"] = (
            "Petitioner No. 1" if first_party == "Wife" else "Petitioner No. 2"
        )
        enriched["petitioner_no_1_party"] = first_party
        enriched["petitioner_no_2_party"] = second_party
        enriched["petitioner_no_1_name"] = husband_name if first_party == "Husband" else wife_name
        enriched["petitioner_no_2_name"] = wife_name if second_party == "Wife" else husband_name
        enriched["party_role_summary"] = (
            f"Mutual consent divorce. {first_party} is Petitioner No. 1 and "
            f"{second_party} is Petitioner No. 2."
        )
        enriched["petitioner_name"] = enriched["petitioner_no_1_name"]
        enriched["respondent_name"] = enriched["petitioner_no_2_name"]

    elif divorce_type == "Contested":
        filing_party = contested_filed_by or "Husband"
        responding_party = "Wife" if filing_party == "Husband" else "Husband"

        enriched["husband_role_label"] = (
            "Petitioner" if filing_party == "Husband" else "Respondent"
        )
        enriched["wife_role_label"] = (
            "Petitioner" if filing_party == "Wife" else "Respondent"
        )
        enriched["petitioner_party"] = filing_party
        enriched["respondent_party"] = responding_party
        enriched["petitioner_name"] = husband_name if filing_party == "Husband" else wife_name
        enriched["respondent_name"] = wife_name if responding_party == "Wife" else husband_name
        enriched["party_role_summary"] = (
            f"Contested divorce. {filing_party} is the Petitioner and "
            f"{responding_party} is the Respondent."
        )

    return enriched

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
# Existing endpoint: extract_fields
# -------------------------------------------------------------------
@document_bp.route("/extract_fields", methods=["POST"])
def extract_fields():
    """Return backend-defined fields for a document type."""
    doc_type = normalize_document_type(request.form.get("document_type", "power_of_attorney"))
    subtype = (request.form.get("subtype") or "").strip()
    language = normalize_generation_language(request.form.get("language", "English"))
    fields = get_fields_for_document_type(doc_type, subtype=subtype)
    fields = localize_field_schema(fields, language=language)
    return jsonify(fields)


@document_bp.route("/document_subtypes", methods=["GET"])
def document_subtypes():
    """Return available subtypes for a document type (if configured)."""
    doc_type = normalize_document_type(request.args.get("document_type"))
    return jsonify(get_subtypes_for_document_type(doc_type))

# -------------------------------------------------------------------
# New endpoint: upload_reference
# -------------------------------------------------------------------
@document_bp.route("/upload_reference", methods=["POST"])
def upload_reference():
    """Upload a reference document, attach backend-defined fields, save file and metadata."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty file"}), 400

    doc_type = normalize_document_type(request.form.get("document_type", "power_of_attorney"))
    subtype = (request.form.get("subtype") or "").strip()
    language = normalize_generation_language(request.form.get("language", "English"))
    ext = os.path.splitext(file.filename)[1].lower()

    # Generate unique ID and save file
    doc_id = str(uuid.uuid4())
    filename = f"{doc_id}{ext}"
    filepath = os.path.join(UPLOADS_FOLDER, filename)
    file.save(filepath)

    # Use backend-defined fields (no AI extraction)
    fields = get_fields_for_document_type(doc_type, subtype=subtype)
    fields = localize_field_schema(fields, language=language)

    # Save metadata
    metadata = load_metadata()
    metadata[doc_id] = {
        "original_name": file.filename,
        "filename": filename,
        "document_type": doc_type,
        "subtype": subtype,
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
    doc_type_filter = normalize_document_type(request.args.get("document_type"))
    metadata = load_metadata()
    result = []
    for doc_id, info in metadata.items():
        info_doc_type = normalize_document_type(info.get("document_type"))
        if doc_type_filter and info_doc_type != doc_type_filter:
            continue
        result.append({
            "id": doc_id,
            "original_name": info["original_name"],
            "document_type": info_doc_type,
            "subtype": info.get("subtype", ""),
            "timestamp": info["timestamp"]
        })
    return jsonify(result)

# -------------------------------------------------------------------
# New endpoint: get_reference/<doc_id>
# -------------------------------------------------------------------
@document_bp.route("/get_reference/<doc_id>", methods=["GET"])
def get_reference(doc_id):
    """Return current backend-defined fields for the reference document type."""
    metadata = load_metadata()
    info = metadata.get(doc_id)
    if not info:
        return jsonify({"error": "Document not found"}), 404
    doc_type = normalize_document_type(info.get("document_type", "power_of_attorney"))
    subtype = (info.get("subtype") or "").strip()
    language = normalize_generation_language(request.args.get("language", "English"))
    fields = get_fields_for_document_type(doc_type, subtype=subtype)
    fields = localize_field_schema(fields, language=language)
    return jsonify(fields)

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
            response = send_from_directory(
                PREVIEW_FOLDER,
                os.path.basename(pdf_path),
                mimetype="application/pdf",
                as_attachment=False
            )
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Headers"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
            return response
        except Exception as e:
            return jsonify({"error": f"Conversion failed: {str(e)}"}), 500

    # ✅ If already PDF → show directly
    elif ext == ".pdf":
        response = send_from_directory(
            UPLOADS_FOLDER,
            filename,
            mimetype="application/pdf",
            as_attachment=False
        )
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        return response

    # ✅ TXT → show inline
    elif ext == ".txt":
        response = send_from_directory(
            UPLOADS_FOLDER,
            filename,
            mimetype="text/plain",
            as_attachment=False
        )
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        return response

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
      - or no reference at all, in which case Gemini drafts from fields only.
    Accepts optional 'format' field: 'table' (use document-specific table template) or 'blank' (use blank template).
    """
    document_type = normalize_document_type(request.form.get("document_type"))
    fields_json = request.form.get("fields", "{}")
    # Read format parameter (default to 'table' for backward compatibility)
    format_type = request.form.get("format", "table")  # 'table' or 'blank'
    language = normalize_generation_language(request.form.get("language", "English"))
    font_family = normalize_font_family(request.form.get("font_family", SUPPORTED_FONT_FAMILIES[0]))
    font_size = normalize_font_size(request.form.get("font_size", DEFAULT_FONT_SIZE))

    try:
        fields = json.loads(fields_json)
    except:
        return jsonify({"error": "Invalid fields JSON"}), 400

    paper_size = normalize_paper_size(fields.get("paper_size"))
    line_spacing = normalize_line_spacing(fields.get("line_spacing"))
    margin_size = normalize_margin_size(fields.get("margin_size"))

    if document_type == "divorce_paper":
        fields = enrich_divorce_fields(fields)

    localized_fields = localize_field_values(fields, language=language)

    reference_id = request.form.get("reference_id")
    reference_text = ""
    has_reference_context = False
    field_schema = get_fields_for_document_type(document_type)

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
        has_reference_context = True
    elif "reference_file" in request.files and request.files["reference_file"].filename:
        # Use uploaded file
        file = request.files["reference_file"]
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
        has_reference_context = True

    # Determine which template to use based on format_type
    template_map = {
        "power_of_attorney": "power_of_attorney_template.docx",
        "gift_deed": "gift_deed_template.docx",
        "rental_agreement": "rental_agreement_template.docx",
        "partnership_deed": "partnership_deed_template.docx",
        "affidavit": "affidavit_template.docx",
        "will_and_testament": "will_testament_template.docx",
        "bail_application": "bail_application_template.docx",
        "loan_agreement": "loan_agreement_template.docx",
    }

    blank_template = "blank_template.docx"
    template_path = None

    if not has_reference_context:
        blank_path = os.path.join(TEMPLATES_FOLDER, blank_template)
        if os.path.exists(blank_path):
            template_path = blank_path
        else:
            return jsonify({"error": "Blank template not found on server"}), 500
    elif format_type == "blank":
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

    # Ask Gemini to produce the final document text either from the reference
    # or from the field values alone when no reference was provided.
    try:
        if has_reference_context:
            final_document_text = fill_document_with_fields(
                reference_text,
                localized_fields,
                document_type,
                language=language,
            )
        else:
            final_document_text = generate_document_from_fields_only(
                document_type,
                localized_fields,
                field_schema=field_schema,
                language=language,
            )
            document_title = get_document_title(document_type)
            stripped_document = final_document_text.lstrip()
            normalized_start = stripped_document[:len(document_title)].upper()
            if normalized_start != document_title:
                final_document_text = f"{document_title}\n\n{stripped_document}"
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
    while os.path.exists(os.path.join(GENERATED_DOCS_FOLDER, output_filename)):
        counter += 1
        output_filename = f"{base_filename}_{counter}.docx"

    output_path = os.path.join(GENERATED_DOCS_FOLDER, output_filename)
    try:
        # Load the server‑side template (preserves tables, formatting)
        doc = DocxDocument(template_path)
        replace_placeholders(doc, localized_fields)
        apply_font_settings(doc, font_family, font_size)
        apply_document_layout_settings(doc, paper_size, line_spacing, margin_size)
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
                    p.paragraph_format.line_spacing = line_spacing
                    apply_font_to_run(p.runs[0], font_family, font_size)
                    body.insert(table_paragraph_index, p._element)
        else:
            # If no table exists, append normally
            for text in gen_paragraphs:
                if text.strip():
                    p = doc.add_paragraph(text.strip())
                    p.paragraph_format.line_spacing = line_spacing
                    apply_font_to_run(p.runs[0], font_family, font_size)


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
        directory = get_generated_file_directory(filename)
        return send_from_directory(
            directory,
            filename,
            as_attachment=as_attachment,
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






















