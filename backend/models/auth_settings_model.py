from datetime import datetime

from werkzeug.security import check_password_hash, generate_password_hash

from database import db


class AuthSettings(db.Model):
    __tablename__ = "auth_settings"

    id = db.Column(db.Integer, primary_key=True, default=1)
    username = db.Column(db.String(120), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def verify_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_public_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
