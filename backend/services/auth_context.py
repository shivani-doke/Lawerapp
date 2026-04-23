from flask import request

from models.app_user_model import AppUser


def get_request_username(default="admin"):
    header_username = (request.headers.get("X-Username") or "").strip()
    if header_username:
        return header_username

    query_username = (request.args.get("username") or "").strip()
    if query_username:
        return query_username

    form_username = (request.form.get("username") or "").strip()
    if form_username:
        return form_username

    json_data = request.get_json(silent=True) or {}
    json_username = (json_data.get("username") or "").strip()
    if json_username:
        return json_username

    return default


def get_request_user_email(default=None):
    header_email = (request.headers.get("X-User-Email") or "").strip()
    if header_email:
        return header_email

    query_email = (request.args.get("email") or "").strip()
    if query_email:
        return query_email

    return default


def get_request_firm_name(default=None):
    header_firm_name = (request.headers.get("X-Firm-Name") or "").strip()
    if header_firm_name:
        return header_firm_name

    query_firm_name = (request.args.get("firm_name") or "").strip()
    if query_firm_name:
        return query_firm_name

    form_firm_name = (request.form.get("firm_name") or "").strip()
    if form_firm_name:
        return form_firm_name

    json_data = request.get_json(silent=True) or {}
    json_firm_name = (json_data.get("firm_name") or "").strip()
    if json_firm_name:
        return json_firm_name

    return default


def get_current_user(default="admin"):
    email = get_request_user_email(default=None)
    if email:
        return AppUser.query.filter_by(email=email).first()

    username = get_request_username(default=default)
    if not username:
        return None
    if "@" in username:
        user_by_email = AppUser.query.filter_by(email=username).first()
        if user_by_email:
            return user_by_email
    firm_name = get_request_firm_name(default=None)
    if firm_name:
        return AppUser.query.filter_by(
            username=username,
            firm_name=firm_name,
        ).first()

    users = AppUser.query.filter_by(username=username).all()
    if len(users) == 1:
        return users[0]
    return None


def get_current_firm(default="Default Firm"):
    user = get_current_user(default=None)
    if user and (user.firm_name or "").strip():
        return user.firm_name.strip()
    return default


def can_manage_billing():
    user = get_current_user(default=None)
    return bool(user and user.can_manage_billing)
