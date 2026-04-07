# app.py
from flask import Flask
from flask_cors import CORS
from sqlalchemy import inspect, text
from database import db
from config import Config

from routes.email_routes import email_bp
from routes.auth_routes import auth_bp
from routes.client_routes import client_bp  # NEW
from routes.payment_routes import payment_bp
from routes.document_routes import document_bp
from routes.dashboard_routes import dashboard_bp
from routes.ai_routes import ai_bp
from models.app_user_model import AppUser
from models.payment_model import Payment


def ensure_client_columns():
    inspector = inspect(db.engine)
    existing_columns = {
        column["name"] for column in inspector.get_columns("clients")
    }
    required_columns = {
        "owner_username": "ALTER TABLE clients ADD COLUMN owner_username VARCHAR(120) DEFAULT 'admin'",
        "age": "ALTER TABLE clients ADD COLUMN age VARCHAR(10)",
        "occupation": "ALTER TABLE clients ADD COLUMN occupation VARCHAR(120)",
        "address": "ALTER TABLE clients ADD COLUMN address TEXT",
        "pan_number": "ALTER TABLE clients ADD COLUMN pan_number VARCHAR(20)",
        "aadhar_number": "ALTER TABLE clients ADD COLUMN aadhar_number VARCHAR(20)",
        "fee_amount": "ALTER TABLE clients ADD COLUMN fee_amount FLOAT DEFAULT 0",
    }

    for column_name, ddl in required_columns.items():
        if column_name not in existing_columns:
            db.session.execute(text(ddl))

    if "owner_username" in existing_columns or "owner_username" in required_columns:
        db.session.execute(
            text(
                "UPDATE clients SET owner_username = 'admin' "
                "WHERE owner_username IS NULL OR owner_username = ''"
            )
        )

    db.session.commit()


def ensure_admin_user():
    if AppUser.query.filter_by(username="admin").first():
        return

    user = AppUser(username="admin", is_admin=True)
    user.set_password("admin123")
    db.session.add(user)
    db.session.commit()


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app)
    db.init_app(app)

    with app.app_context():
        db.create_all()
        ensure_admin_user()
        if "clients" in inspect(db.engine).get_table_names():
            ensure_client_columns()

    # Register blueprints
    app.register_blueprint(email_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(client_bp)  # NEW
    app.register_blueprint(payment_bp)
    app.register_blueprint(document_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(ai_bp)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(debug=True)
