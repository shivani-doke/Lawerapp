# backend/services/document_service.py
import os
from werkzeug.utils import secure_filename

UPLOAD_FOLDER = "uploads"
GENERATED_FOLDER = "generated_docs"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(GENERATED_FOLDER, exist_ok=True)

def save_uploaded_file(file):
    filename = secure_filename(file.filename)
    path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(path)
    return path