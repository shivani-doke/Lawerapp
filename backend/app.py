# app.py
from flask import Flask
from flask_cors import CORS
from database import db
from config import Config

from routes.email_routes import email_bp
from routes.client_routes import client_bp  # NEW
from routes.document_routes import document_bp
from routes.dashboard_routes import dashboard_bp
from routes.ai_routes import ai_bp

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app)
    db.init_app(app)

    with app.app_context():
        db.create_all()

    # Register blueprints
    app.register_blueprint(email_bp)
    app.register_blueprint(client_bp)  # NEW
    app.register_blueprint(document_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(ai_bp)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(debug=True)

