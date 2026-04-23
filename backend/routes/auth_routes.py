from flask import Blueprint, jsonify, request

from database import db
from models.app_user_model import AppUser
from models.client_model import Client
from models.firm_model import Firm
from models.payment_model import Payment
from services.auth_context import get_current_user

auth_bp = Blueprint("auth_bp", __name__, url_prefix="/auth")

DEFAULT_FIRM_NAME = "Default Firm"
DEFAULT_MAX_TEAM_MEMBERS = 10


def normalize_firm_name(value):
    return " ".join((value or "").strip().split())


def require_firm_admin():
    user = get_current_user(default=None)
    if not user:
        return None, (jsonify({"error": "Authentication required"}), 401)
    if (user.role or "").strip().lower() != "firm_admin":
        return None, (jsonify({"error": "Only firm admins can manage team members"}), 403)
    return user, None


def require_platform_admin():
    user = get_current_user(default=None)
    if not user:
        return None, (jsonify({"error": "Authentication required"}), 401)
    if not user.is_platform_admin:
        return None, (jsonify({"error": "Only the master admin can manage firms"}), 403)
    return user, None


def require_authenticated_firm_user():
    user = get_current_user(default=None)
    if not user:
        return None, (jsonify({"error": "Authentication required"}), 401)
    if user.is_platform_admin:
        return None, (jsonify({"error": "Use the master panel for this action"}), 403)
    return user, None


def normalize_role(value):
    role = (value or "").strip().lower()
    if role in {"firm_member", "lawyer"}:
        return "lawyer"
    if role == "firm_admin":
        return "firm_admin"
    if role == "platform_admin":
        return "platform_admin"
    return role


def normalize_team_limit(value, default=DEFAULT_MAX_TEAM_MEMBERS):
    if value in (None, ""):
        return default
    try:
        limit = int(value)
    except (TypeError, ValueError):
        return None
    return limit if limit > 0 else None


def serialize_user_session(user):
    firm = Firm.query.filter_by(id=user.firm_id).first() if user.firm_id else None
    return {
        **user.to_public_dict(),
        "firm": firm.to_dict() if firm else None,
        "app_display_name": firm.app_display_name if firm else None,
        "app_logo_data": firm.app_logo_data if firm else None,
        "max_team_members": (
            firm.max_team_members if firm and firm.max_team_members else DEFAULT_MAX_TEAM_MEMBERS
        ),
    }


def firm_user_count(firm_id):
    return AppUser.query.filter_by(firm_id=firm_id).count()


def get_or_create_admin_user():
    user = AppUser.query.filter_by(email="admin@default-firm.local").first()
    if not user:
        user = AppUser.query.filter_by(username="admin", firm_name=DEFAULT_FIRM_NAME).first()
    if user:
        if not user.firm_name:
            user.firm_name = DEFAULT_FIRM_NAME
        user.role = "platform_admin"
        user.is_admin = user.can_manage_billing
        db.session.commit()
        return user

    user = AppUser(
        username="admin",
        firm_name=DEFAULT_FIRM_NAME,
        role="platform_admin",
        is_admin=True,
    )
    user.set_password("admin123")
    db.session.add(user)
    db.session.commit()
    return user


@auth_bp.route("/master-login", methods=["POST"])
def master_login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    get_or_create_admin_user()
    if not email:
        return jsonify({"error": "Email is required"}), 400

    user = AppUser.query.filter_by(email=email).first()

    if not user or not user.verify_password(password):
        return jsonify({"error": "Invalid email or password"}), 401

    if not user.is_platform_admin:
        return jsonify({"error": "This account cannot use master login"}), 403

    return jsonify({
        "message": "Login successful",
        **serialize_user_session(user),
    })


@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    get_or_create_admin_user()
    if not email:
        return jsonify({"error": "Email is required"}), 400

    user = AppUser.query.filter_by(email=email).first()

    if not user or not user.verify_password(password):
        return jsonify({"error": "Invalid email or password"}), 401

    if user.is_platform_admin:
        return jsonify({"error": "Use master login for this account"}), 403

    return jsonify({
        "message": "Login successful",
        **serialize_user_session(user),
    })


@auth_bp.route("/signup", methods=["POST"])
def signup():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    full_name = (data.get("full_name") or "").strip()
    username = (data.get("username") or full_name or email.split("@")[0]).strip()
    password = data.get("password") or ""
    firm_name = normalize_firm_name(data.get("firm_name"))

    get_or_create_admin_user()

    if not full_name:
        return jsonify({"error": "Full name is required"}), 400

    if not email:
        return jsonify({"error": "Email is required"}), 400

    if len(password) < 4:
        return jsonify({"error": "Password must be at least 4 characters"}), 400

    if not firm_name:
        return jsonify({"error": "Firm name is required"}), 400

    existing_user = AppUser.query.filter_by(email=email).first()
    if existing_user:
        return jsonify({"error": "Email already exists"}), 409

    existing_firm_user = AppUser.query.filter_by(firm_name=firm_name).first()
    if existing_firm_user:
        return jsonify({
            "error": "This firm already exists. Please ask the firm admin to create user accounts from inside the app."
        }), 409

    firm = Firm(name=firm_name)
    db.session.add(firm)
    db.session.flush()
    user = AppUser(
        username=username,
        email=email,
        full_name=full_name,
        firm_id=firm.id,
        firm_name=firm_name,
        role="firm_admin",
        is_admin=True,
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify({
        "message": "Signup successful",
        **serialize_user_session(user),
    })


@auth_bp.route("/firms", methods=["GET"])
def list_firms():
    _, error_response = require_platform_admin()
    if error_response:
        return error_response

    firms = Firm.query.order_by(Firm.name.asc()).all()
    firm_payload = []
    for firm in firms:
        users = AppUser.query.filter_by(firm_id=firm.id).order_by(AppUser.created_at.asc()).all()
        admin_users = [user for user in users if normalize_role(user.role) == "firm_admin"]
        lawyer_users = [user for user in users if normalize_role(user.role) == "lawyer"]
        client_count = Client.query.filter_by(firm_id=firm.id).count()
        payment_count = Payment.query.filter_by(firm_id=firm.id).count()
        firm_payload.append({
            **firm.to_dict(),
            "user_count": len(users),
            "admin_count": len(admin_users),
            "lawyer_count": len(lawyer_users),
            "client_count": client_count,
            "payment_count": payment_count,
            "primary_admin": admin_users[0].to_public_dict() if admin_users else None,
        })

    return jsonify(firm_payload)


@auth_bp.route("/firms", methods=["POST"])
def create_firm_credentials():
    _, error_response = require_platform_admin()
    if error_response:
        return error_response

    data = request.get_json(silent=True) or {}
    firm_name = normalize_firm_name(data.get("firm_name"))
    admin_full_name = (data.get("admin_full_name") or "").strip()
    admin_email = (data.get("admin_email") or "").strip().lower()
    admin_username = (
        data.get("admin_username") or admin_full_name or admin_email.split("@")[0]
    ).strip()
    admin_password = data.get("admin_password") or ""
    max_team_members = normalize_team_limit(data.get("max_team_members"))

    if not firm_name:
        return jsonify({"error": "Firm name is required"}), 400
    if not admin_full_name:
        return jsonify({"error": "Admin full name is required"}), 400
    if not admin_email:
        return jsonify({"error": "Admin email is required"}), 400
    if len(admin_password) < 4:
        return jsonify({"error": "Admin password must be at least 4 characters"}), 400
    if max_team_members is None:
        return jsonify({"error": "Max team member limit must be at least 1"}), 400

    existing_firm = Firm.query.filter_by(name=firm_name).first()
    if existing_firm:
        return jsonify({"error": "Firm already exists"}), 409

    existing_email = AppUser.query.filter_by(email=admin_email).first()
    if existing_email:
        return jsonify({"error": "Admin email already exists"}), 409

    firm = Firm(name=firm_name, max_team_members=max_team_members)
    db.session.add(firm)
    db.session.flush()

    admin_user = AppUser(
        username=admin_username,
        email=admin_email,
        full_name=admin_full_name,
        firm_id=firm.id,
        firm_name=firm_name,
        role="firm_admin",
        is_admin=True,
    )
    admin_user.set_password(admin_password)
    db.session.add(admin_user)
    db.session.commit()

    return jsonify({
        "message": "Firm created successfully",
        "firm": firm.to_dict(),
        "admin_user": admin_user.to_public_dict(),
    }), 201


@auth_bp.route("/firms/<int:firm_id>", methods=["PUT"])
def update_firm(firm_id):
    _, error_response = require_platform_admin()
    if error_response:
        return error_response

    firm = Firm.query.filter_by(id=firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404

    data = request.get_json(silent=True) or {}
    max_team_members = normalize_team_limit(data.get("max_team_members"))
    if max_team_members is None:
        return jsonify({"error": "Max team member limit must be at least 1"}), 400

    current_users = firm_user_count(firm.id)
    if max_team_members < current_users:
        return jsonify({
            "error": f"Limit cannot be lower than the current team size ({current_users})",
        }), 400

    firm.max_team_members = max_team_members
    db.session.commit()

    return jsonify({
        "message": "Firm updated successfully",
        "firm": firm.to_dict(),
    })


@auth_bp.route("/firms/<int:firm_id>", methods=["DELETE"])
def delete_firm(firm_id):
    _, error_response = require_platform_admin()
    if error_response:
        return error_response

    firm = Firm.query.filter_by(id=firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404
    if firm.name == DEFAULT_FIRM_NAME:
        return jsonify({"error": "Default firm cannot be deleted"}), 400

    Payment.query.filter_by(firm_id=firm.id).delete(synchronize_session=False)
    Client.query.filter_by(firm_id=firm.id).delete(synchronize_session=False)
    AppUser.query.filter_by(firm_id=firm.id).delete(synchronize_session=False)
    db.session.delete(firm)
    db.session.commit()

    return jsonify({"message": "Firm deleted successfully"})


@auth_bp.route("/team", methods=["GET"])
def list_team_members():
    current_user, error_response = require_authenticated_firm_user()
    if error_response:
        return error_response

    users = AppUser.query.filter_by(firm_id=current_user.firm_id).order_by(
        AppUser.role.asc(),
        AppUser.username.asc(),
    ).all()
    return jsonify([user.to_public_dict() for user in users])


@auth_bp.route("/team/summary", methods=["GET"])
def get_team_summary():
    current_user, error_response = require_authenticated_firm_user()
    if error_response:
        return error_response

    firm = Firm.query.filter_by(id=current_user.firm_id).first()
    team_count = firm_user_count(current_user.firm_id)
    return jsonify({
        "firm": firm.to_dict() if firm else None,
        "team_count": team_count,
        "remaining_slots": max((firm.max_team_members if firm else 0) - team_count, 0),
    })


@auth_bp.route("/firm-branding", methods=["GET"])
def get_firm_branding():
    current_user, error_response = require_firm_admin()
    if error_response:
        return error_response

    firm = Firm.query.filter_by(id=current_user.firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404

    return jsonify({
        "firm_id": firm.id,
        "firm_name": firm.name,
        "app_display_name": firm.app_display_name,
        "app_logo_data": firm.app_logo_data,
    })


@auth_bp.route("/firm-branding", methods=["PUT"])
def update_firm_branding():
    current_user, error_response = require_firm_admin()
    if error_response:
        return error_response

    firm = Firm.query.filter_by(id=current_user.firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404

    data = request.get_json(silent=True) or {}
    app_display_name = (data.get("app_display_name") or "").strip()
    app_logo_data = data.get("app_logo_data")
    clear_logo = data.get("clear_logo") == True

    if not app_display_name:
        return jsonify({"error": "App name is required"}), 400
    if len(app_display_name) > 200:
        return jsonify({"error": "App name must be 200 characters or fewer"}), 400

    if clear_logo:
        firm.app_logo_data = None
    elif app_logo_data is not None:
        app_logo_data = str(app_logo_data).strip()
        if app_logo_data and len(app_logo_data) > 2_000_000:
            return jsonify({"error": "Logo image is too large"}), 400
        firm.app_logo_data = app_logo_data or None

    firm.app_display_name = app_display_name
    db.session.commit()

    return jsonify({
        "message": "Branding updated successfully",
        "firm": firm.to_dict(),
        "app_display_name": firm.app_display_name,
        "app_logo_data": firm.app_logo_data,
    })


@auth_bp.route("/team", methods=["POST"])
def create_team_member():
    current_user, error_response = require_firm_admin()
    if error_response:
        return error_response

    data = request.get_json(silent=True) or {}
    full_name = (data.get("full_name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    username = (data.get("username") or full_name or email.split("@")[0]).strip()
    password = data.get("password") or ""
    requested_role = normalize_role(data.get("role") or "lawyer")
    allowed_roles = {"firm_admin", "lawyer"}

    if not full_name:
        return jsonify({"error": "Full name is required"}), 400

    if not email:
        return jsonify({"error": "Email is required"}), 400

    if len(password) < 4:
        return jsonify({"error": "Password must be at least 4 characters"}), 400

    if requested_role not in allowed_roles:
        return jsonify({"error": "Invalid role selected"}), 400

    existing_user = AppUser.query.filter_by(email=email).first()
    if existing_user:
        return jsonify({"error": "Email already exists"}), 409

    firm = Firm.query.filter_by(id=current_user.firm_id).first()
    if not firm:
        return jsonify({"error": "Firm not found"}), 404

    current_team_count = firm_user_count(current_user.firm_id)
    if current_team_count >= (firm.max_team_members or DEFAULT_MAX_TEAM_MEMBERS):
        return jsonify({
            "error": f"Team limit reached for {firm.name}. Increase the limit from the master panel to add more members.",
        }), 409

    user = AppUser(
        username=username,
        email=email,
        full_name=full_name,
        firm_id=current_user.firm_id,
        firm_name=current_user.firm_name,
        role=requested_role,
        is_admin=requested_role == "firm_admin",
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify({
        "message": "Team member created successfully",
        **serialize_user_session(user),
    }), 201


@auth_bp.route("/team/<int:user_id>", methods=["DELETE"])
def delete_team_member(user_id):
    current_user, error_response = require_firm_admin()
    if error_response:
        return error_response

    user = AppUser.query.filter_by(
        id=user_id,
        firm_id=current_user.firm_id,
    ).first()
    if not user:
        return jsonify({"error": "Team member not found"}), 404

    if user.id == current_user.id:
        return jsonify({"error": "You cannot delete your own account"}), 400

    if user.role == "firm_admin":
        admin_count = AppUser.query.filter_by(
            firm_id=current_user.firm_id,
            role="firm_admin",
        ).count()
        if admin_count <= 1:
            return jsonify({"error": "The last firm admin cannot be deleted"}), 400

    db.session.delete(user)
    db.session.commit()

    return jsonify({"message": "Team member deleted successfully"})


@auth_bp.route("/settings", methods=["GET"])
def get_auth_settings():
    admin_user = get_or_create_admin_user()
    active_user = get_current_user(default=None) or admin_user
    return jsonify({
        "default_admin_username": admin_user.username,
        "signup_enabled": True,
        **serialize_user_session(active_user),
    })


@auth_bp.route("/settings", methods=["PUT"])
def update_auth_settings():
    data = request.get_json(silent=True) or {}

    current_username = (data.get("current_username") or "").strip()
    current_email = (data.get("current_email") or "").strip().lower()
    current_password = data.get("current_password") or ""
    new_username = (data.get("new_username") or "").strip()
    new_email = (data.get("new_email") or "").strip().lower()
    new_full_name = (data.get("new_full_name") or "").strip()
    new_password = data.get("new_password") or ""

    get_or_create_admin_user()
    user = None
    if current_email:
        user = AppUser.query.filter_by(email=current_email).first()
    elif current_username:
        user = AppUser.query.filter_by(username=current_username).first()

    if not user or not user.verify_password(current_password):
        return jsonify({"error": "Current email or password is incorrect"}), 401

    if not user.can_manage_billing:
        return jsonify({"error": "Only firm admins can change login credentials"}), 403

    if not new_username:
        new_username = user.username

    if not new_email:
        return jsonify({"error": "New email is required"}), 400

    if len(new_password) < 4:
        return jsonify({"error": "New password must be at least 4 characters"}), 400

    existing_user = AppUser.query.filter_by(email=new_email).first()
    if existing_user and existing_user.id != user.id:
        return jsonify({"error": "Email already exists"}), 409

    user.username = new_username
    user.email = new_email
    user.full_name = new_full_name or user.full_name
    user.set_password(new_password)
    db.session.commit()

    return jsonify({
        "message": "Login credentials updated successfully",
        **serialize_user_session(user),
    })
