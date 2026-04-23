from datetime import datetime

from database import db


class Firm(db.Model):
    __tablename__ = "firms"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False, unique=True)
    max_team_members = db.Column(db.Integer, nullable=False, default=10)
    app_display_name = db.Column(db.String(200), nullable=True)
    app_logo_data = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "max_team_members": self.max_team_members,
            "app_display_name": self.app_display_name,
            "app_logo_data": self.app_logo_data,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
