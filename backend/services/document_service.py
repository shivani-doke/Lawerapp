import subprocess
import os

GENERATED_FOLDER = "generated"
os.makedirs(GENERATED_FOLDER, exist_ok=True)

def convert_docx_to_pdf(docx_path):
    try:
        subprocess.run([
            r"C:\Program Files\LibreOffice\program\soffice.exe",
            "--headless",
            "--convert-to",
            "pdf",
            "--outdir",
            GENERATED_FOLDER,
            docx_path
        ], check=True) 

        pdf_filename = os.path.basename(docx_path).replace(".docx", ".pdf")
        pdf_path = os.path.join(GENERATED_FOLDER, pdf_filename)

        return pdf_path

    except Exception as e:
        raise Exception(f"PDF conversion failed: {str(e)}")
    


    
# # backend/services/document_service.py
# import os
# from werkzeug.utils import secure_filename

# UPLOAD_FOLDER = "uploads"
# GENERATED_FOLDER = "generated_docs"


# os.makedirs(UPLOAD_FOLDER, exist_ok=True)
# os.makedirs(GENERATED_FOLDER, exist_ok=True)

# def save_uploaded_file(file):
#     filename = secure_filename(file.filename)
#     path = os.path.join(UPLOAD_FOLDER, filename)
#     file.save(path)
#     return path