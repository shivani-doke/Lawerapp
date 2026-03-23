# backend/services/document_service.py
import subprocess
import os

GENERATED_FOLDER = "generated"
PREVIEW_FOLDER = "preview_cache"

# Ensure folders exist
os.makedirs(GENERATED_FOLDER, exist_ok=True)
os.makedirs(PREVIEW_FOLDER, exist_ok=True)


def convert_docx_to_pdf(docx_path, output_dir):
    """
    Convert DOCX to PDF using LibreOffice.
    Returns PDF path.
    """
    try:
        subprocess.run([
            r"C:\Program Files\LibreOffice\program\soffice.exe",
            "--headless",
            "--convert-to", "pdf",
            "--outdir", output_dir,
            docx_path
        ], check=True)

        pdf_filename = os.path.basename(docx_path).replace(".docx", ".pdf")
        return os.path.join(output_dir, pdf_filename)

    except Exception as e:
        # ✅ Only one raise here
        raise Exception(f"PDF conversion failed: {str(e)}")