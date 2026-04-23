from datetime import datetime

from werkzeug.security import check_password_hash, generate_password_hash

from database import db
from models.firm_model import Firm


class AppUser(db.Model):
    __tablename__ = "app_users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(255), nullable=True, unique=True)
    full_name = db.Column(db.String(255), nullable=True)
    firm_id = db.Column(db.Integer, db.ForeignKey("firms.id"), nullable=True, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    firm_name = db.Column(db.String(200), nullable=False, default="Default Firm")
    role = db.Column(db.String(50), nullable=False, default="firm_admin")
    is_admin = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    firm = db.relationship("Firm", backref=db.backref("users", lazy=True))

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def verify_password(self, password):
        return check_password_hash(self.password_hash, password)

    @property
    def display_name(self):
        return (self.full_name or self.username or "").strip()

    @property
    def is_platform_admin(self):
        return (self.role or "").strip().lower() == "platform_admin"

    @property
    def can_manage_billing(self):
        return (self.role or "").strip().lower() in {"platform_admin", "firm_admin"}

    def to_public_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "display_name": self.display_name,
            "firm_id": self.firm_id,
            "firm_name": self.firm_name,
            "role": self.role,
            "is_admin": self.is_admin,
            "is_platform_admin": self.is_platform_admin,
            "can_manage_billing": self.can_manage_billing,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
