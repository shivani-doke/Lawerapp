from datetime import datetime

from database import db


class Payment(db.Model):
    __tablename__ = "payments"

    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(
        db.Integer,
        db.ForeignKey("clients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    owner_username = db.Column(db.String(120), nullable=False, default="admin")
    amount = db.Column(db.Float, nullable=False)
    payment_mode = db.Column(db.String(50), nullable=True)
    payment_date = db.Column(db.String(20), nullable=False)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    client = db.relationship("Client", backref=db.backref("payments", lazy=True))

    def to_dict(self):
        return {
            "id": self.id,
            "client_id": self.client_id,
            "owner_username": self.owner_username,
            "amount": self.amount,
            "payment_mode": self.payment_mode,
            "payment_date": self.payment_date,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
