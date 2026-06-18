import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta
from html import escape
from urllib.parse import urlencode

import requests
from flask import current_app

from database import db
from models.firm_model import Firm

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"
GMAIL_SEND_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"
GMAIL_SCOPES = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/gmail.send",
]


def _config_value(name):
    return (current_app.config.get(name) or "").strip()


def gmail_oauth_ready():
    return all(
        [
            _config_value("GOOGLE_CLIENT_ID"),
            _config_value("GOOGLE_CLIENT_SECRET"),
            _config_value("GOOGLE_OAUTH_REDIRECT_URI"),
        ]
    )


def _base64url_encode_bytes(value):
    return base64.urlsafe_b64encode(value).decode("utf-8").rstrip("=")


def _base64url_decode_to_bytes(value):
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(f"{value}{padding}")


def _state_secret():
    return _config_value("SECRET_KEY") or "legalai-dev-secret"


def create_signed_state(payload):
    body = dict(payload or {})
    body["ts"] = int(time.time())
    encoded = _base64url_encode_bytes(
        json.dumps(body, separators=(",", ":")).encode("utf-8")
    )
    signature = hmac.new(
        _state_secret().encode("utf-8"),
        encoded.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded}.{signature}"


def parse_signed_state(value, max_age_seconds=900):
    if "." not in (value or ""):
        raise ValueError("Invalid state")

    encoded, signature = value.split(".", 1)
    expected_signature = hmac.new(
        _state_secret().encode("utf-8"),
        encoded.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(signature, expected_signature):
        raise ValueError("Invalid state signature")

    payload = json.loads(_base64url_decode_to_bytes(encoded).decode("utf-8"))
    issued_at = int(payload.get("ts") or 0)
    if issued_at <= 0 or (time.time() - issued_at) > max_age_seconds:
        raise ValueError("Expired state")
    return payload


def build_google_connect_url(user, firm):
    if not gmail_oauth_ready():
        raise ValueError("Google OAuth is not configured on the server.")
    if not user or not firm:
        raise ValueError("Firm admin context is required.")

    state = create_signed_state(
        {
            "user_id": user.id,
            "firm_id": firm.id,
            "firm_name": firm.name,
            "provider": "gmail",
        }
    )
    query = urlencode(
        {
            "client_id": _config_value("GOOGLE_CLIENT_ID"),
            "redirect_uri": _config_value("GOOGLE_OAUTH_REDIRECT_URI"),
            "response_type": "code",
            "access_type": "offline",
            "prompt": "consent",
            "include_granted_scopes": "true",
            "scope": " ".join(GMAIL_SCOPES),
            "state": state,
        }
    )
    return f"{GOOGLE_AUTH_URL}?{query}"


def _token_payload_for_code(code):
    return {
        "client_id": _config_value("GOOGLE_CLIENT_ID"),
        "client_secret": _config_value("GOOGLE_CLIENT_SECRET"),
        "redirect_uri": _config_value("GOOGLE_OAUTH_REDIRECT_URI"),
        "grant_type": "authorization_code",
        "code": code,
    }


def _token_payload_for_refresh(refresh_token):
    return {
        "client_id": _config_value("GOOGLE_CLIENT_ID"),
        "client_secret": _config_value("GOOGLE_CLIENT_SECRET"),
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
    }


def _fetch_google_tokens(payload):
    response = requests.post(
        GOOGLE_TOKEN_URL,
        data=payload,
        timeout=20,
    )
    data = response.json()
    if response.status_code >= 400:
        raise ValueError(
            data.get("error_description")
            or data.get("error")
            or "Failed to authenticate with Google."
        )
    return data


def _fetch_google_userinfo(access_token):
    response = requests.get(
        GOOGLE_USERINFO_URL,
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=20,
    )
    data = response.json()
    if response.status_code >= 400:
        raise ValueError(
            data.get("error_description")
            or data.get("error")
            or "Unable to load Gmail account profile."
        )
    return data


def connect_gmail_account(firm, code):
    token_data = _fetch_google_tokens(_token_payload_for_code(code))
    access_token = (token_data.get("access_token") or "").strip()
    refresh_token = (token_data.get("refresh_token") or "").strip()
    if not access_token or not refresh_token:
        raise ValueError(
            "Google did not return a usable mailbox token. Please try connecting again."
        )

    userinfo = _fetch_google_userinfo(access_token)
    sender_email = (userinfo.get("email") or "").strip().lower()
    if not sender_email:
        raise ValueError("Google did not return the sender email address.")

    expires_in = int(token_data.get("expires_in") or 3600)
    firm.gmail_sender_email = sender_email
    firm.gmail_access_token = access_token
    firm.gmail_refresh_token = refresh_token
    firm.gmail_token_expiry = datetime.utcnow() + timedelta(seconds=expires_in - 60)
    firm.gmail_scopes = " ".join(token_data.get("scope", "").split()) or " ".join(
        GMAIL_SCOPES
    )
    firm.gmail_connected_at = datetime.utcnow()
    db.session.commit()
    return sender_email


def disconnect_gmail_account(firm):
    firm.gmail_sender_email = None
    firm.gmail_access_token = None
    firm.gmail_refresh_token = None
    firm.gmail_token_expiry = None
    firm.gmail_scopes = None
    firm.gmail_connected_at = None
    db.session.commit()


def gmail_mailbox_status(firm):
    connected = bool(firm and firm.gmail_refresh_token and firm.gmail_sender_email)
    return {
        "provider": "gmail",
        "configured": gmail_oauth_ready(),
        "connected": connected,
        "sender_email": firm.gmail_sender_email if connected else None,
        "connected_at": (
            firm.gmail_connected_at.isoformat()
            if connected and firm.gmail_connected_at
            else None
        ),
    }


def _ensure_access_token(firm):
    if not firm or not firm.gmail_refresh_token:
        raise ValueError("No Gmail mailbox is connected for this firm.")

    if (
        firm.gmail_access_token
        and firm.gmail_token_expiry
        and firm.gmail_token_expiry > datetime.utcnow()
    ):
        return firm.gmail_access_token

    token_data = _fetch_google_tokens(
        _token_payload_for_refresh(firm.gmail_refresh_token)
    )
    access_token = (token_data.get("access_token") or "").strip()
    if not access_token:
        raise ValueError("Google refresh did not return an access token.")

    expires_in = int(token_data.get("expires_in") or 3600)
    firm.gmail_access_token = access_token
    firm.gmail_token_expiry = datetime.utcnow() + timedelta(seconds=expires_in - 60)
    if token_data.get("scope"):
        firm.gmail_scopes = " ".join(str(token_data["scope"]).split())
    db.session.commit()
    return access_token


def send_gmail_update(firm, to_email, subject, message, client_name=None):
    access_token = _ensure_access_token(firm)
    safe_client_name = escape((client_name or "Client").strip() or "Client")
    paragraphs = [
        f"<p>Dear {safe_client_name},</p>",
        f"<p>{escape((message or '').strip()).replace(chr(10), '<br>')}</p>",
        "<br>",
        f"<p>Best regards,<br>{escape((firm.gmail_sender_email or '').strip())}</p>",
    ]
    html_body = "".join(paragraphs)
    raw_message = (
        f"To: {to_email}\r\n"
        f"From: {firm.gmail_sender_email}\r\n"
        f"Subject: {subject}\r\n"
        "MIME-Version: 1.0\r\n"
        "Content-Type: text/html; charset=UTF-8\r\n"
        "\r\n"
        f"{html_body}"
    )
    encoded_message = _base64url_encode_bytes(raw_message.encode("utf-8"))
    response = requests.post(
        GMAIL_SEND_URL,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        json={"raw": encoded_message},
        timeout=20,
    )
    data = response.json() if response.content else {}
    if response.status_code >= 400:
        raise ValueError(
            data.get("error", {}).get("message")
            or "Gmail rejected the outgoing message."
        )
    return data
