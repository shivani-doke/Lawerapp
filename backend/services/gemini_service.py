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

def generate_document_from_fields_only(document_type, field_values, field_schema=None):
    schema_lines = []
    for field in field_schema or []:
        if not isinstance(field, dict):
            continue
        schema_lines.append(json.dumps(field, ensure_ascii=False))

    fields_description = "\n".join(
        [f"- {key}: {json.dumps(value, ensure_ascii=False)}" for key, value in field_values.items()]
    )
    schema_description = "\n".join(schema_lines) if schema_lines else "No schema provided."

    prompt = f"""
You are a legal drafting engine.

You are given:
1. A legal document type
2. A structured field schema
3. User-provided values

Your task is to draft a complete legal first draft from scratch using only the
provided values. Do not rely on any reference document.

DOCUMENT TYPE:
{document_type}

FIELD SCHEMA:
{schema_description}

FIELD VALUES:
{fields_description}

RULES:
- Draft a complete, professional legal document for the given document type.
- Start the document with a clear standalone title derived from the document type.
- The first non-empty line must be the document title in uppercase.
- Use clear headings, clauses, and signature sections where appropriate.
- Use only the provided facts.
- Do NOT invent names, dates, addresses, money amounts, or legal facts.
- If some optional information is missing, omit that detail cleanly.
- If a required section needs missing information, write it in neutral generic form
  without inventing facts.
- Keep the tone formal and legally styled.
- Do NOT include commentary, explanations, checklists, or notes to the user.
- Output only the final document text.
- Do NOT use markdown.
- Do NOT wrap the answer in code fences.
"""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config={"temperature": 0.2}
        )
        return response.text.strip()
    except Exception as e:
        raise Exception(f"Gemini draft generation failed: {str(e)}")

def replace_placeholders(doc, field_values):
    def replace_in_paragraph(paragraph):
        for run in paragraph.runs:
            for key, value in field_values.items():
                placeholder = f"{{{{{key}}}}}"
                if placeholder in run.text:
                    run.text = run.text.replace(placeholder, str(value))

    # Replace in normal paragraphs
    for paragraph in doc.paragraphs:
        replace_in_paragraph(paragraph)

    # Replace inside tables
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    replace_in_paragraph(paragraph)
