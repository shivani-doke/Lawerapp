# # backend/services/gemini_service.py
import os
import json
import re
from google import genai
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

def extract_fields_from_document(document_text, document_type):
    prompt = f"""
You are an AI system that converts legal document templates into dynamic form fields.

Your task is to analyze the legal document and extract ALL values that can change
from one client to another.

These values will later be replaced by user input in a document generation system.

IMPORTANT RULE:
If a value could be different for another client, it must be extracted as a field.

DO NOT extract fixed legal clauses or paragraphs.

--------------------------------
FIELDS THAT MUST BE EXTRACTED
--------------------------------

1. Personal Details
- Name
- Age
- Gender
- Occupation
- Relationship (father, mother, daughter, etc.)

2. Identification Details
- PAN number
- Aadhaar number
- Passport number
- Government ID numbers

3. Contact Details
- Address
- Phone number
- Email

4. Legal Roles
Extract fields for parties such as:
- Principal
- Agent / Attorney
- Seller
- Buyer
- Donor
- Donee
- Landlord
- Tenant
- Partner
- Witness

Examples:
principal_name
agent_name
seller_name
buyer_name
donor_name
donee_name

5. Dates
- Execution date
- Agreement date
- Registration date
- Deed date

6. Location Fields
- City
- State
- Property location
- Registration office

7. Property Details (IMPORTANT)
If the document contains property description, extract fields such as:

- Flat number
- Building name
- Floor number
- Survey number
- CTS number
- Area (sq ft / sq m)
- Terrace area
- Parking details

8. Property Boundaries
Extract boundary placeholders if present:

boundary_east
boundary_west
boundary_north
boundary_south

9. Legal Reference Details
- Deed number
- Registration number
- Share percentage
- Undivided share

10. Monetary Values
- Sale amount
- Deposit amount
- Consideration amount
- Stamp duty

--------------------------------
FIELD NAMING RULES
--------------------------------

All field names must be:

snake_case

Examples:

principal_name
principal_pan
buyer_address
flat_number
survey_number
execution_date
sale_amount
boundary_east

--------------------------------
FIELD TYPE RULES
--------------------------------

Use only these types:

"text"
"number"
"date"
"email"

Examples:
Age → number
Amount → number
Date → date
Name → text
Address → text

--------------------------------
OUTPUT FORMAT
--------------------------------

Return ONLY a JSON array.

Each field must contain:

"name"
"label"
"type"
"hint"
"required"

Example:

[
  {{
    "name": "principal_name",
    "label": "Principal Full Name",
    "type": "text",
    "hint": "Enter principal full name",
    "required": true
  }},
  {{
    "name": "execution_date",
    "label": "Execution Date",
    "type": "date",
    "hint": "Select execution date",
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
        return [] 

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

OUTPUT RULES:

- Do NOT repeat any part of the document.
- Output the document only once, from beginning to end.
- Do NOT include any introductory or concluding remarks.
- Output ONLY the final document text.

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