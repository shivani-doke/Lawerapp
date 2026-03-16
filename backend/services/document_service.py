#backend/services/document_service.py
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


# import subprocess
# import os

# GENERATED_FOLDER = "generated"
# os.makedirs(GENERATED_FOLDER, exist_ok=True)

# def convert_docx_to_pdf(docx_path):
#     try:
#         subprocess.run([
#             r"C:\Program Files\LibreOffice\program\soffice.exe",
#             "--headless",
#             "--convert-to",
#             "pdf",
#             "--outdir",
#             GENERATED_FOLDER,
#             docx_path
#         ], check=True) 

#         pdf_filename = os.path.basename(docx_path).replace(".docx", ".pdf")
#         pdf_path = os.path.join(GENERATED_FOLDER, pdf_filename)

#         return pdf_path

#     except Exception as e:
#         raise Exception(f"PDF conversion failed: {str(e)}")
    


 