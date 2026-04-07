# backend/models/client_model.py

from database import db

class Client(db.Model):
    __tablename__ = "clients"

    id = db.Column(db.Integer, primary_key=True)
    owner_username = db.Column(db.String(120), nullable=False, default="admin")
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    age = db.Column(db.String(10), nullable=True)
    occupation = db.Column(db.String(120), nullable=True)
    address = db.Column(db.Text, nullable=True)
    pan_number = db.Column(db.String(20), nullable=True)
    aadhar_number = db.Column(db.String(20), nullable=True)
    fee_amount = db.Column(db.Float, nullable=True, default=0.0)
    case_type = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(50), nullable=False)
    notes = db.Column(db.Text, nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "owner_username": self.owner_username,
            "name": self.name,
            "email": self.email,
            "phone": self.phone,
            "age": self.age,
            "occupation": self.occupation,
            "address": self.address,
            "pan_number": self.pan_number,
            "aadhar_number": self.aadhar_number,
            "fee_amount": self.fee_amount,
            "case_type": self.case_type,
            "status": self.status,
            "notes": self.notes
        }
