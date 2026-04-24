# backend/services/document_service.py
import os
import subprocess

from config import Config

GENERATED_FOLDER = "generated"
GENERATED_DOCS_FOLDER = "generated_docs"
PREVIEW_FOLDER = "preview_cache"

# Ensure folders exist
os.makedirs(GENERATED_FOLDER, exist_ok=True)
os.makedirs(GENERATED_DOCS_FOLDER, exist_ok=True)
os.makedirs(PREVIEW_FOLDER, exist_ok=True)


def convert_docx_to_pdf(docx_path, output_dir):
    """
    Convert DOCX to PDF using LibreOffice.
    Returns PDF path.
    """
    libreoffice_path = (Config.LIBREOFFICE_PATH or "soffice").strip() or "soffice"

    try:
        subprocess.run(
            [
                libreoffice_path,
                "--headless",
                "--convert-to",
                "pdf",
                "--outdir",
                output_dir,
                docx_path,
            ],
            check=True,
        )

        pdf_filename = os.path.basename(docx_path).replace(".docx", ".pdf")
        return os.path.join(output_dir, pdf_filename)

    except Exception as e:
        raise Exception(
            f"PDF conversion failed using LibreOffice binary '{libreoffice_path}': {str(e)}"
        )
