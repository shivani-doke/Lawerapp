from flask import Blueprint, jsonify, request

from database import db
from models.app_user_model import AppUser

auth_bp = Blueprint("auth_bp", __name__, url_prefix="/auth")


def get_or_create_admin_user():
    user = AppUser.query.filter_by(username="admin").first()
    if user:
        return user

    user = AppUser(username="admin", is_admin=True)
    user.set_password("admin123")
    db.session.add(user)
    db.session.commit()
    return user


@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    get_or_create_admin_user()
    user = AppUser.query.filter_by(username=username).first()

    if not user or not user.verify_password(password):
        return jsonify({"error": "Invalid username or password"}), 401

    return jsonify(
        {
            "message": "Login successful",
            "username": user.username,
            "is_admin": user.is_admin,
        }
    )


@auth_bp.route("/signup", methods=["POST"])
def signup():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    get_or_create_admin_user()

    if not username:
        return jsonify({"error": "Username is required"}), 400

    if len(password) < 4:
        return jsonify({"error": "Password must be at least 4 characters"}), 400

    existing_user = AppUser.query.filter_by(username=username).first()
    if existing_user:
        return jsonify({"error": "Username already exists"}), 409

    user = AppUser(username=username, is_admin=False)
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify(
        {
            "message": "Signup successful",
            "username": user.username,
            "is_admin": user.is_admin,
        }
    )


@auth_bp.route("/settings", methods=["GET"])
def get_auth_settings():
    admin_user = get_or_create_admin_user()
    return jsonify(
        {
            "default_admin_username": admin_user.username,
            "signup_enabled": True,
        }
    )


@auth_bp.route("/settings", methods=["PUT"])
def update_auth_settings():
    data = request.get_json(silent=True) or {}

    current_username = (data.get("current_username") or "").strip()
    current_password = data.get("current_password") or ""
    new_username = (data.get("new_username") or "").strip()
    new_password = data.get("new_password") or ""

    get_or_create_admin_user()
    user = AppUser.query.filter_by(username=current_username).first()

    if not user or not user.verify_password(current_password):
        return jsonify({"error": "Current username or password is incorrect"}), 401

    if not new_username:
        return jsonify({"error": "New username is required"}), 400

    if len(new_password) < 4:
        return jsonify({"error": "New password must be at least 4 characters"}), 400

    existing_user = AppUser.query.filter_by(username=new_username).first()
    if existing_user and existing_user.id != user.id:
        return jsonify({"error": "Username already exists"}), 409

    user.username = new_username
    user.set_password(new_password)
    db.session.commit()

    return jsonify(
        {
            "message": "Login credentials updated successfully",
            "username": user.username,
        }
    )
