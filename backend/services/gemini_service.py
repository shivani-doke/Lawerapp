import os
import json
import re
from google import genai
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

def extract_fields_from_document(document_text, document_type):
    prompt = f"""
You are a legal document data extraction system.

Analyze the following legal reference document from start to end and extract ONLY the
CLIENT INFORMATION fields that must be filled by the user to customize the legal document.

IMPORTANT:
Extract ONLY personal or entity details. DO NOT extract legal clauses,
paragraphs, or conditions.

ALLOWED FIELD TYPES TO EXTRACT:

1. Personal details
   - Name
   - Age
   - Gender
   - Occupation

2. Identification details
   - PAN number
   - Aadhaar number
   - Passport number
   - ID numbers

3. Contact details
   - Address
   - Email
   - Phone number

4. Legal role details
   - Principal
   - Agent
   - Seller
   - Buyer
   - Tenant
   - Landlord
   - Witness

5. Date fields
   - Execution date
   - Agreement date

6. Location fields
   - City
   - Registration office
   - Property location (short field only)

FIELD NAMING RULES (VERY IMPORTANT):

Use the following exact field names when they appear in the document:

Principal fields
principal_name

Agent / Attorney
agent_name

Witness fields
witness1_name
witness1_address
witness2_name
witness2_address

If the document contains witnesses, always extract TWO witness fields using the exact names above.

DO NOT EXTRACT:
- Legal clauses
- Paragraph text
- Conditions
- Powers granted
- Agreement descriptions

OUTPUT FORMAT:
Return ONLY a JSON array.

Each field must contain:

- "name": snake_case identifier
- "label": readable label
- "type": one of "text", "date", "number", "email"
- "hint": short placeholder
- "required": true or false

Example output:

[
  {{
    "name": "principal_name",
    "label": "Principal Full Name",
    "type": "text",
    "hint": "Enter principal full name",
    "required": true
  }},
  {{
    "name": "principal_pan",
    "label": "Principal PAN Number",
    "type": "text",
    "hint": "Enter PAN number",
    "required": true
  }},
  {{
    "name": "principal_address",
    "label": "Principal Address",
    "type": "text",
    "hint": "Enter full address",
    "required": true
  }}
]

REFERENCE DOCUMENT:
{document_text}
"""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        text = response.text.strip()
        json_str = re.sub(r'^```json\s*|\s*```$', '', text, flags=re.MULTILINE)

        fields = json.loads(json_str)

        if not isinstance(fields, list):
            raise ValueError("Response is not a list")

        return fields

    except Exception as e:
        print(f"Gemini extraction error: {e}")
        return get_default_fields(document_type)

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        text = response.text.strip()

        json_str = re.sub(r'^```json\s*|\s*```$', '', text, flags=re.MULTILINE)

        fields = json.loads(json_str)

        if not isinstance(fields, list):
            raise ValueError("Response is not a list")

        return fields

    except Exception as e:
        print(f"Gemini extraction error: {e}")
        return get_default_fields(document_type)
def fill_document_with_fields(reference_text, field_values, document_type):
    fields_description = "\n".join([f"- {key}: {value}" for key, value in field_values.items()])

    prompt = f"""
You are a legal document rendering engine.

You are given:
1. A reference legal document (type: {document_type})
2. A structured set of field values

Your task is to produce the FINAL document by inserting the provided field values
while preserving the ENTIRE reference document exactly from beginning to end.

CRITICAL PRESERVATION RULES:

- The output must contain ALL content from the reference document.
- Do NOT remove any paragraph.
- Do NOT shorten the document.
- Do NOT summarize.
- Do NOT rewrite legal clauses.
- Do NOT change wording except where factual values are replaced.
- Preserve:
  • Title
  • Headings
  • Clause numbering
  • Indentation
  • Paragraph breaks
  • Spacing
  • Capitalization
  • Punctuation
  • Legal terminology
  • Signature blocks
  • Witness sections
  • Footer text
- Maintain exact structure from start to end.

REPLACEMENT RULES:

- Replace only variable factual information using provided field values.
- If a field value is not provided, leave the original text unchanged.
- Do NOT invent missing data.
- Do NOT add commentary or explanation.
- **Do NOT repeat any part of the document.** Output the document only once, from beginning to end.
- **Do NOT include any introductory or concluding remarks.** Output only the final document text.

Output ONLY the final complete document text.
Do NOT use markdown.
Do NOT wrap in code blocks.

REFERENCE DOCUMENT (FULL TEXT):
--------------------------------
{reference_text}

FIELD VALUES:
--------------------------------
{fields_description}

FINAL DOCUMENT:
"""
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config={"temperature": 0.1}
        )
        return response.text.strip()
    except Exception as e:
        raise Exception(f"Gemini generation failed: {str(e)}")

def get_default_fields(doc_type):
    if doc_type == "power_of_attorney":
        return [
            {"name": "principal", "label": "Principal's Full Name", "type": "text", "hint": "Person granting authority", "required": True},
            {"name": "agent", "label": "Agent's Full Name", "type": "text", "hint": "Person receiving authority", "required": True},
            {"name": "purpose", "label": "Purpose / Scope of Authority", "type": "multiline", "hint": "Describe the powers...", "required": True},
            {"name": "date", "label": "Date of Execution", "type": "date", "hint": "dd-mm-yyyy", "required": True},
            {"name": "conditions", "label": "Conditions & Limitations", "type": "multiline", "hint": "Any restrictions...", "required": False}
        ]
    return []

def replace_placeholders(doc, field_values):

    # Replace in paragraphs
    for para in doc.paragraphs:
        for run in para.runs:
            for key, value in field_values.items():
                placeholder = f"{{{{{key}}}}}"
                if placeholder in run.text:
                    run.text = run.text.replace(placeholder, str(value))

    # Replace in tables
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for para in cell.paragraphs:
                    for run in para.runs:
                        for key, value in field_values.items():
                            placeholder = f"{{{{{key}}}}}"
                            if placeholder in run.text:
                                run.text = run.text.replace(placeholder, str(value))


                                
# # backend/services/gemini_service.py
# import os
# import json
# import re
# from google import genai
# from dotenv import load_dotenv

# load_dotenv()

# # Initialize the Gemini client (reused for all calls)
# client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

# def extract_fields_from_document(document_text, document_type):
#     """
#     Ask Gemini to list all variable fields present in the document.
#     Returns a list of dicts with name, label, type, hint, required.
#     """
#     prompt = f"""
# You are a legal document analyst. Given a reference document (type: {document_type}), identify all the fields that a user would need to fill in to customise it.

# Output a JSON array of objects. Each object must have:
# - "name": snake_case identifier (e.g., "principal_name")
# - "label": human‑readable label (e.g., "Principal's Full Name")
# - "type": one of "text", "date", "multiline", "number", "email"
# - "hint": a short placeholder hint
# - "required": boolean (true if essential, false if optional)

# Only output the JSON array, nothing else.

# DOCUMENT:
# {document_text}
# """
#     try:
#         response = client.models.generate_content(
#             model="gemini-2.5-flash",
#             contents=prompt

#         )
#         text = response.text.strip()
#         # Remove possible markdown fences
#         json_str = re.sub(r'^```json\s*|\s*```$', '', text, flags=re.MULTILINE)
#         fields = json.loads(json_str)
#         if not isinstance(fields, list):
#             raise ValueError("Response is not a list")
#         return fields
#     except Exception as e:
#         print(f"Gemini extraction error: {e}")
#         # Fallback to default fields for the document type
#         return get_default_fields(document_type)

# def fill_document_with_fields(reference_text, field_values, document_type):
#     """
#     Ask Gemini to produce the final document by inserting the provided field values
#     into the reference document. The reference document may contain placeholders or
#     natural language gaps; Gemini should intelligently fill them.
#     """
#     fields_description = "\n".join([f"- {key}: {value}" for key, value in field_values.items()])

#     prompt = f"""
# You are a legal document rendering engine.

# You are given:
# 1. A reference legal document (type: {document_type})
# 2. A structured set of field values

# Your task is to produce the FINAL document by inserting the provided field values
# while preserving the ENTIRE reference document exactly from beginning to end.

# CRITICAL PRESERVATION RULES:

# - The output must contain ALL content from the reference document.
# - Do NOT remove any paragraph.
# - Do NOT shorten the document.
# - Do NOT summarize.
# - Do NOT rewrite legal clauses.
# - Do NOT change wording except where factual values are replaced.
# - Preserve:
#   • Title
#   • Headings
#   • Clause numbering
#   • Indentation
#   • Paragraph breaks
#   • Spacing
#   • Capitalization
#   • Punctuation
#   • Legal terminology
#   • Signature blocks
#   • Witness sections
#   • Footer text
# - Maintain exact structure from start to end.

# REPLACEMENT RULES:

# - Replace only variable factual information using provided field values.
# - If a field value is not provided, leave the original text unchanged.
# - Do NOT invent missing data.
# - Do NOT add commentary or explanation.
# - Output ONLY the final complete document text.
# - Do NOT use markdown.
# - Do NOT wrap in code blocks.

# REFERENCE DOCUMENT (FULL TEXT):
# --------------------------------
# {reference_text}

# FIELD VALUES:
# --------------------------------
# {fields_description}

# FINAL DOCUMENT:
# """
#     try:
#         response = client.models.generate_content(
#             model="gemini-2.5-flash",
#             contents=prompt,
#             config={
#                 "temperature": 0.1 # Deterministic output
                
#             }
            
#         )
#         return response.text.strip()
#     except Exception as e:
#         raise Exception(f"Gemini generation failed: {str(e)}")

# def get_default_fields(doc_type):
#     if doc_type == "power_of_attorney":
#         return [
#             {"name": "principal", "label": "Principal's Full Name", "type": "text", "hint": "Person granting authority", "required": True},
#             {"name": "agent", "label": "Agent's Full Name", "type": "text", "hint": "Person receiving authority", "required": True},
#             {"name": "purpose", "label": "Purpose / Scope of Authority", "type": "multiline", "hint": "Describe the powers...", "required": True},
#             {"name": "date", "label": "Date of Execution", "type": "date", "hint": "dd-mm-yyyy", "required": True},
#             {"name": "conditions", "label": "Conditions & Limitations", "type": "multiline", "hint": "Any restrictions...", "required": False}
#         ]
#     return []