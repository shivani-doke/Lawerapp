# backend/routes/document_routes.py

import os
import json
import tempfile
import uuid
import re
from html import escape, unescape
from html.parser import HTMLParser
from datetime import datetime
from flask import Blueprint, request, jsonify, send_from_directory, abort
from werkzeug.utils import secure_filename

from docx import Document as DocxDocument
from docx.enum.text import WD_ALIGN_PARAGRAPH
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
from services.auth_context import get_request_username

SUPPORTED_FONT_FAMILIES = (
    "Times New Roman",
    "Arial",
    "Calibri",
    "Cambria",
    "Book Antiqua",
    "Bookman Old Style",
    "Candara",
    "Century Gothic",
    "Comic Sans MS",
    "Consolas",
    "Constantia",
    "Corbel",
    "Courier New",
    "Georgia",
    "Garamond",
    "Lucida Console",
    "Lucida Sans Unicode",
    "Palatino Linotype",
    "Segoe UI",
    "Sylfaen",
    "Trebuchet MS",
    "Verdana",
    "Tahoma",
    "Nirmala UI",
    "Mangal",
    "Aparajita",
    "Kokila",
    "Utsaah",
)

DEFAULT_FONT_SIZE = 14
MIN_FONT_SIZE = 8
MAX_FONT_SIZE = 72

# Folder where template DOCX files are stored
TEMPLATES_FOLDER = "templates"
os.makedirs(TEMPLATES_FOLDER, exist_ok=True)

# Folder for uploaded reference documents
UPLOADS_FOLDER = "uploads"
os.makedirs(UPLOADS_FOLDER, exist_ok=True)
METADATA_FILE = os.path.join(UPLOADS_FOLDER, "metadata.json")
GENERATED_METADATA_FILE = os.path.join(GENERATED_FOLDER, "generated_metadata.json")

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


def apply_default_font_style(doc, font_family, font_size):
    normal_style = doc.styles["Normal"]
    normal_style.font.name = font_family
    normal_style.font.size = Pt(font_size)
    style_properties = normal_style.element.get_or_add_rPr()
    style_properties.rFonts.set(qn("w:ascii"), font_family)
    style_properties.rFonts.set(qn("w:hAnsi"), font_family)
    style_properties.rFonts.set(qn("w:eastAsia"), font_family)
    style_properties.rFonts.set(qn("w:cs"), font_family)


def apply_font_settings(doc, font_family, font_size):
    apply_default_font_style(doc, font_family, font_size)

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


def clear_document_body(doc):
    body = doc.element.body
    for child in list(body):
        if child.tag.endswith("sectPr"):
            continue
        body.remove(child)


def get_generated_html_filepath(filename):
    stem, _ = os.path.splitext(filename)
    return os.path.join(GENERATED_DOCS_FOLDER, f"{stem}.editor.html")


def save_generated_html_content(filename, html_content):
    html_path = get_generated_html_filepath(filename)
    with open(html_path, "w", encoding="utf-8") as html_file:
        html_file.write(html_content or "")


def load_generated_html_content(filename):
    html_path = get_generated_html_filepath(filename)
    if not os.path.exists(html_path):
        return None
    with open(html_path, "r", encoding="utf-8") as html_file:
        return html_file.read()


def get_matching_generated_docx_filename(filename):
    stem, ext = os.path.splitext(filename)
    if ext.lower() == ".docx":
        return filename
    if ext.lower() == ".pdf":
        return f"{stem}.docx"
    return None


def build_html_from_docx(filepath):
    doc = DocxDocument(filepath)
    blocks = []

    for paragraph in doc.paragraphs:
        tag = "p"
        if paragraph.style is not None:
            style_name = str(paragraph.style.name or "").lower()
            if "heading 1" in style_name:
                tag = "h1"
            elif "heading 2" in style_name:
                tag = "h2"
            elif "heading 3" in style_name:
                tag = "h3"

        styles = []
        if paragraph.alignment == WD_ALIGN_PARAGRAPH.CENTER:
            styles.append("text-align:center")
        elif paragraph.alignment == WD_ALIGN_PARAGRAPH.RIGHT:
            styles.append("text-align:right")
        elif paragraph.alignment == WD_ALIGN_PARAGRAPH.JUSTIFY:
            styles.append("text-align:justify")

        if paragraph.paragraph_format.left_indent:
            indent_pt = paragraph.paragraph_format.left_indent.pt
            if indent_pt:
                styles.append(f"margin-left:{indent_pt:.0f}pt")

        segments = []
        if paragraph.runs:
            for run in paragraph.runs:
                text = escape(run.text or "")
                if not text and not run._element.xpath(".//w:br"):
                    continue
                text = text.replace("\n", "<br>")
                if run._element.xpath(".//w:br"):
                    text += "<br>"

                inline_styles = []
                if run.font.name:
                    inline_styles.append(f"font-family:{escape(run.font.name)}")
                if run.font.size:
                    inline_styles.append(f"font-size:{run.font.size.pt:.0f}px")
                if run.bold:
                    inline_styles.append("font-weight:bold")
                if run.italic:
                    inline_styles.append("font-style:italic")
                if run.underline:
                    inline_styles.append("text-decoration:underline")
                if run.font.strike:
                    inline_styles.append("text-decoration:line-through")

                if inline_styles:
                    segments.append(
                        f'<span style="{"; ".join(inline_styles)}">{text}</span>'
                    )
                else:
                    segments.append(text)
        else:
            segments.append("<br>")

        style_attr = f' style="{"; ".join(styles)}"' if styles else ""
        blocks.append(f"<{tag}{style_attr}>{''.join(segments) or '<br>'}</{tag}>")

    return "".join(blocks) if blocks else "<p></p>"


def html_to_plain_text(html_content):
    html_content = str(html_content or "")
    if not html_content.strip():
        return ""
    text = re.sub(r"(?i)<br\s*/?>", "\n", html_content)
    text = re.sub(r"(?i)</(p|div|h1|h2|h3|li|ul|ol|blockquote)>", "\n", text)
    text = re.sub(r"(?i)<hr[^>]*>", "\n----------------------------------------\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("&nbsp;", " ")
    text = text.replace("&amp;", "&")
    text = text.replace("&lt;", "<")
    text = text.replace("&gt;", ">")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def parse_editor_font_size(value, default_size):
    size_map = {
        "1": 8,
        "2": 10,
        "3": 12,
        "4": 14,
        "5": 18,
        "6": 24,
        "7": 32,
    }
    parsed = str(value or "").strip()
    return size_map.get(parsed, default_size)


def parse_inline_style(style_value):
    style_map = {}
    for declaration in str(style_value or "").split(";"):
        if ":" not in declaration:
            continue
        key, value = declaration.split(":", 1)
        style_map[key.strip().lower()] = value.strip()
    return style_map


class EditorHtmlParser(HTMLParser):
    def __init__(self, default_font_family, default_font_size):
        super().__init__(convert_charrefs=False)
        self.default_font_family = default_font_family
        self.default_font_size = default_font_size
        self.blocks = []
        self.current_block = None
        self.style_stack = [self._base_style()]
        self.list_stack = []
        self.indent_stack = [0.0]

    def _base_style(self):
        return {
            "bold": False,
            "italic": False,
            "underline": False,
            "strike": False,
            "font_family": self.default_font_family,
            "font_size": self.default_font_size,
        }

    def _current_style(self):
        return dict(self.style_stack[-1])

    def _extract_alignment(self, attrs):
        style_map = parse_inline_style(attrs.get("style"))
        alignment = (style_map.get("text-align") or "").strip().lower()
        if alignment in {"center", "right", "left", "justify"}:
            return alignment
        return None

    def _extract_indent_points(self, attrs):
        style_map = parse_inline_style(attrs.get("style"))
        margin_left = (style_map.get("margin-left") or "").strip().lower()
        if not margin_left:
            return 0.0

        match = re.search(r"(\d+(?:\.\d+)?)", margin_left)
        if not match:
            return 0.0

        numeric = float(match.group(1))
        if margin_left.endswith("px"):
            return numeric * 0.75
        if margin_left.endswith("pt"):
            return numeric
        if margin_left.endswith("in"):
            return numeric * 72.0
        if margin_left.endswith("cm"):
            return numeric * 28.3465
        if margin_left.endswith("mm"):
            return numeric * 2.83465
        return numeric

    def _current_indent(self):
        return float(self.indent_stack[-1])

    def _start_block(self, tag, attrs):
        if self.current_block is not None:
            self._finalize_block()
        self.current_block = {
            "tag": tag,
            "align": self._extract_alignment(attrs),
            "indent": self._current_indent() + self._extract_indent_points(attrs),
            "segments": [],
        }

    def _append_text(self, text):
        if text is None:
            return
        if self.current_block is None:
            self._start_block("p", {})
        normalized = unescape(text)
        if not normalized:
            return
        self.current_block["segments"].append((normalized, self._current_style()))

    def _finalize_block(self):
        if self.current_block is None:
            return
        self.blocks.append(self.current_block)
        self.current_block = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        tag = tag.lower()

        if tag in {"p", "div", "h1", "h2", "h3"}:
            self._start_block(tag, attrs)
            return

        if tag == "blockquote":
            extra_indent = self._extract_indent_points(attrs) or 36.0
            self.indent_stack.append(self._current_indent() + extra_indent)
            return

        if tag in {"ul", "ol"}:
            self.list_stack.append({"ordered": tag == "ol", "index": 0})
            return

        if tag == "li":
            self._start_block("li", attrs)
            if self.list_stack:
                current_list = self.list_stack[-1]
                if current_list["ordered"]:
                    current_list["index"] += 1
                    self._append_text(f"{current_list['index']}. ")
                else:
                    self._append_text("• ")
            return

        if tag == "br":
            self._append_text("\n")
            return

        if tag == "hr":
            self._finalize_block()
            self.blocks.append({"tag": "hr", "align": None, "segments": []})
            return

        style = self._current_style()
        pushed = False

        if tag in {"b", "strong"}:
            style["bold"] = True
            pushed = True
        elif tag in {"i", "em"}:
            style["italic"] = True
            pushed = True
        elif tag == "u":
            style["underline"] = True
            pushed = True
        elif tag in {"s", "strike"}:
            style["strike"] = True
            pushed = True
        elif tag == "font":
            if attrs.get("face"):
                style["font_family"] = attrs.get("face")
            if attrs.get("size"):
                style["font_size"] = parse_editor_font_size(
                    attrs.get("size"),
                    self.default_font_size,
                )
            pushed = True
        elif tag == "span":
            style_map = parse_inline_style(attrs.get("style"))
            font_family = style_map.get("font-family")
            if font_family:
                style["font_family"] = font_family.split(",")[0].strip().strip('"').strip("'")
            font_size = style_map.get("font-size")
            if font_size:
                match = re.search(r"(\d+(?:\.\d+)?)", font_size)
                if match:
                    style["font_size"] = int(float(match.group(1)))
            font_weight = style_map.get("font-weight", "").lower()
            if font_weight in {"bold", "600", "700", "800", "900"}:
                style["bold"] = True
            font_style = style_map.get("font-style", "").lower()
            if font_style == "italic":
                style["italic"] = True
            text_decoration = style_map.get("text-decoration", "").lower()
            if "underline" in text_decoration:
                style["underline"] = True
            if "line-through" in text_decoration:
                style["strike"] = True
            pushed = True

        if pushed:
            self.style_stack.append(style)

    def handle_endtag(self, tag):
        tag = tag.lower()

        if tag in {"p", "div", "h1", "h2", "h3", "li"}:
            self._finalize_block()
            return

        if tag == "blockquote":
            if len(self.indent_stack) > 1:
                self.indent_stack.pop()
            return

        if tag in {"ul", "ol"}:
            if self.list_stack:
                self.list_stack.pop()
            return

        if tag in {"b", "strong", "i", "em", "u", "s", "strike", "font", "span"}:
            if len(self.style_stack) > 1:
                self.style_stack.pop()

    def handle_data(self, data):
        self._append_text(data)

    def handle_entityref(self, name):
        self._append_text(f"&{name};")

    def handle_charref(self, name):
        self._append_text(f"&#{name};")


def paragraph_alignment_for(value):
    value = str(value or "").strip().lower()
    if value == "center":
        return WD_ALIGN_PARAGRAPH.CENTER
    if value == "right":
        return WD_ALIGN_PARAGRAPH.RIGHT
    if value == "justify":
        return WD_ALIGN_PARAGRAPH.JUSTIFY
    return WD_ALIGN_PARAGRAPH.LEFT


def add_text_to_paragraph(paragraph, text, style, font_family, font_size):
    segments = str(text or "").split("\n")
    for index, segment in enumerate(segments):
        run = paragraph.add_run(segment)
        apply_font_to_run(
            run,
            style.get("font_family") or font_family,
            style.get("font_size") or font_size,
        )
        run.bold = bool(style.get("bold"))
        run.italic = bool(style.get("italic"))
        run.underline = bool(style.get("underline"))
        run.font.strike = bool(style.get("strike"))
        if index < len(segments) - 1:
            run.add_break()


def render_html_document_content(doc, html_content, font_family, font_size, line_spacing):
    parser = EditorHtmlParser(font_family, font_size)
    parser.feed(str(html_content or ""))
    parser.close()
    parser._finalize_block()

    written = False
    for block in parser.blocks:
        if block.get("tag") == "hr":
            paragraph = doc.add_paragraph("----------------------------------------")
            paragraph.paragraph_format.line_spacing = line_spacing
            if paragraph.runs:
                apply_font_to_run(paragraph.runs[0], font_family, font_size)
            written = True
            continue

        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.line_spacing = line_spacing
        paragraph.alignment = paragraph_alignment_for(block.get("align"))
        indent_points = float(block.get("indent") or 0.0)
        if indent_points > 0:
            paragraph.paragraph_format.left_indent = Pt(indent_points)

        tag = block.get("tag")
        if tag == "h1":
            paragraph.alignment = paragraph_alignment_for(block.get("align") or "left")
        elif tag == "h2":
            paragraph.alignment = paragraph_alignment_for(block.get("align") or "left")

        segments = block.get("segments") or []
        if not segments:
            paragraph.add_run("")

        for text, style in segments:
            segment_style = dict(style)
            if tag == "h1":
                segment_style["bold"] = True
                segment_style["font_size"] = max(font_size + 8, 22)
            elif tag == "h2":
                segment_style["bold"] = True
                segment_style["font_size"] = max(font_size + 4, 18)
            elif tag == "h3":
                segment_style["bold"] = True
                segment_style["font_size"] = max(font_size + 2, 16)
            add_text_to_paragraph(
                paragraph,
                text,
                segment_style,
                font_family,
                font_size,
            )
        written = True

    return written


def replace_document_content(filepath, content, font_family, font_size, paper_size, line_spacing, margin_size, html_content=None):
    doc = DocxDocument(filepath)
    clear_document_body(doc)

    written = False
    if str(html_content or "").strip():
        written = render_html_document_content(
            doc,
            html_content,
            font_family,
            font_size,
            line_spacing,
        )

    if not written:
        paragraphs = [part.strip() for part in str(content or "").replace("\r\n", "\n").split("\n\n")]
        for paragraph_text in paragraphs:
            if not paragraph_text:
                continue
            paragraph = doc.add_paragraph(paragraph_text)
            paragraph.paragraph_format.line_spacing = line_spacing
            if paragraph.runs:
                apply_font_to_run(paragraph.runs[0], font_family, font_size)
            written = True

    if not written:
        paragraph = doc.add_paragraph("")
        paragraph.paragraph_format.line_spacing = line_spacing

    if str(html_content or "").strip():
        apply_default_font_style(doc, font_family, font_size)
    else:
        apply_font_settings(doc, font_family, font_size)
    apply_document_layout_settings(doc, paper_size, line_spacing, margin_size)
    doc.save(filepath)

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
    username = get_request_username()
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
        "owner_username": username,
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
    username = get_request_username()
    metadata = load_metadata()
    result = []
    for doc_id, info in metadata.items():
        if (info.get("owner_username") or "admin") != username:
            continue
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
    username = get_request_username()
    metadata = load_metadata()
    info = metadata.get(doc_id)
    if not info:
        return jsonify({"error": "Document not found"}), 404
    if (info.get("owner_username") or "admin") != username:
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
    username = get_request_username(default=None)
    metadata = load_metadata()
    info = metadata.get(doc_id)
    if not info:
        abort(404, description="Document not found")
    if username and (info.get("owner_username") or "admin") != username:
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
    username = get_request_username()
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
        if (info.get("owner_username") or "admin") != username:
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
        generated_metadata = load_generated_metadata()
        timestamp_iso = datetime.now().isoformat()
        generated_metadata[output_filename] = {
            "owner_username": username,
            "timestamp": timestamp_iso,
        }
        generated_metadata[pdf_filename] = {
            "owner_username": username,
            "timestamp": timestamp_iso,
        }
        save_generated_metadata(generated_metadata)
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
        username = get_request_username(default=None)
        ensure_generated_metadata_defaults()
        metadata = load_generated_metadata()
        info = metadata.get(filename)
        if not info:
            return jsonify({"error": "File not found"}), 404
        if username and (info.get("owner_username") or "admin") != username:
            return jsonify({"error": "File not found"}), 404
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
        username = get_request_username(default=None)
        ensure_generated_metadata_defaults()
        metadata = load_generated_metadata()
        info = metadata.get(filename)
        if not info:
            return jsonify({"error": "File not found"}), 404
        if username and (info.get("owner_username") or "admin") != username:
            return jsonify({"error": "File not found"}), 404
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


@document_bp.route("/generated-document-content/<filename>", methods=["GET"])
def get_generated_document_content(filename):
    try:
        username = get_request_username(default=None)
        ensure_generated_metadata_defaults()
        metadata = load_generated_metadata()
        info = metadata.get(filename)
        if not info:
            return jsonify({"error": "File not found"}), 404
        if username and (info.get("owner_username") or "admin") != username:
            return jsonify({"error": "File not found"}), 404

        ext = os.path.splitext(filename)[1].lower()
        if ext not in (".docx", ".txt", ".pdf"):
            return jsonify({"error": "Unsupported file type"}), 400

        resolved_filename = filename
        resolved_ext = ext
        filepath = os.path.join(get_generated_file_directory(filename), filename)

        matching_docx = get_matching_generated_docx_filename(filename)
        if matching_docx:
            matching_docx_path = os.path.join(GENERATED_DOCS_FOLDER, matching_docx)
            if os.path.exists(matching_docx_path):
                resolved_filename = matching_docx
                resolved_ext = ".docx"
                filepath = matching_docx_path

        if not os.path.exists(filepath):
            return jsonify({"error": "File not found"}), 404

        html_content = None
        if resolved_ext == ".docx":
            html_content = load_generated_html_content(resolved_filename)
            if not html_content:
                html_content = build_html_from_docx(filepath)

        content = extract_text_from_file(filepath, resolved_ext)
        if content is None:
            return jsonify({"error": "Failed to extract content"}), 500

        return jsonify(
            {
                "content": content,
                "html": html_content,
                "source_filename": resolved_filename,
            }
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@document_bp.route("/generated-document-content/<filename>", methods=["POST"])
def update_generated_document_content(filename):
    try:
        username = get_request_username(default=None)
        ensure_generated_metadata_defaults()
        metadata = load_generated_metadata()
        info = metadata.get(filename)
        if not info:
            return jsonify({"error": "File not found"}), 404
        if username and (info.get("owner_username") or "admin") != username:
            return jsonify({"error": "File not found"}), 404

        ext = os.path.splitext(filename)[1].lower()
        editable_filename = get_matching_generated_docx_filename(filename)
        if not editable_filename or not editable_filename.lower().endswith(".docx"):
            return jsonify({"error": "Only DOCX documents can be edited"}), 400

        payload = request.get_json(silent=True) or {}
        content = str(payload.get("content", "")).strip()
        html_content = str(payload.get("html", "")).strip()
        font_family = normalize_font_family(
            payload.get("font_family", SUPPORTED_FONT_FAMILIES[0])
        )
        font_size = normalize_font_size(
            payload.get("font_size", DEFAULT_FONT_SIZE)
        )
        line_spacing = normalize_line_spacing(
            payload.get("line_spacing", 1.0)
        )
        if html_content and not content:
            content = html_to_plain_text(html_content)
        if not content:
            return jsonify({"error": "Content is required"}), 400

        docx_path = os.path.join(GENERATED_DOCS_FOLDER, editable_filename)
        if not os.path.exists(docx_path):
            return jsonify({"error": "File not found"}), 404

        replace_document_content(
            docx_path,
            content,
            font_family=font_family,
            font_size=font_size,
            paper_size="A4",
            line_spacing=line_spacing,
            margin_size="Normal",
            html_content=html_content,
        )

        if html_content:
            save_generated_html_content(editable_filename, html_content)

        pdf_filename = editable_filename.replace(".docx", ".pdf")
        pdf_path = convert_docx_to_pdf(docx_path, GENERATED_FOLDER)

        timestamp_iso = datetime.now().isoformat()
        metadata[editable_filename] = {
            **metadata.get(editable_filename, {}),
            "owner_username": username or metadata.get(filename, {}).get("owner_username") or "admin",
            "timestamp": timestamp_iso,
        }
        metadata[pdf_filename] = {
            **metadata.get(pdf_filename, {}),
            "owner_username": username or metadata.get(pdf_filename, {}).get("owner_username") or "admin",
            "timestamp": timestamp_iso,
        }
        save_generated_metadata(metadata)

        return jsonify({
            "message": "Document updated successfully",
            "docx_file": editable_filename,
            "pdf_file": os.path.basename(pdf_path),
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500






















