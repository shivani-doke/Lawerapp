import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "legalai-dev-secret")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    ECOURTS_API_KEY = os.getenv("ECOURTS_API_KEY")
    SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
    FROM_EMAIL = os.getenv("FROM_EMAIL")
    GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
    GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")
    GOOGLE_OAUTH_REDIRECT_URI = os.getenv("GOOGLE_OAUTH_REDIRECT_URI")
    LIBREOFFICE_PATH = os.getenv("LIBREOFFICE_PATH", "soffice")
    SQLALCHEMY_DATABASE_URI = "sqlite:///database.db"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
