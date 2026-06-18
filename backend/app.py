# app.py
from flask import Flask, jsonify, request
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
from routes.ecourts_routes import ecourts_bp
from models.app_user_model import AppUser
from models.client_model import Client
from models.firm_model import Firm
from models.payment_model import Payment
from services.auth_context import get_request_firm_name, get_request_username


def firm_is_over_limit(user):
    if user is None or user.firm_id is None:
        return False

    firm = Firm.query.filter_by(id=user.firm_id).first()
    if not firm:
        return False

    max_team_members = firm.max_team_members or 0
    team_count = AppUser.query.filter_by(firm_id=user.firm_id).count()
    return team_count > max_team_members


def firm_over_limit_message(user):
    if user is None or user.firm_id is None:
        return None

    firm = Firm.query.filter_by(id=user.firm_id).first()
    if not firm:
        return None

    max_team_members = firm.max_team_members or 0
    team_count = AppUser.query.filter_by(firm_id=user.firm_id).count()
    over_limit_by = max(team_count - max_team_members, 0)
    if over_limit_by <= 0:
        return None

    user_label = "user" if over_limit_by == 1 else "users"
    return (
        f"Your firm has {team_count} active users, but the limit is {max_team_members}. "
        f"Your firm admin must delete {over_limit_by} {user_label} before you can continue."
    )


def ensure_firms():
    default_firm = Firm.query.filter_by(name="Default Firm").first()
    if not default_firm:
        db.session.add(Firm(name="Default Firm"))
        db.session.commit()

    existing_firm_names = {firm.name for firm in Firm.query.all()}
    user_firm_names = {
        row[0]
        for row in db.session.execute(
            text("SELECT DISTINCT firm_name FROM app_users WHERE firm_name IS NOT NULL AND firm_name != ''")
        ).fetchall()
    }
    for firm_name in sorted(user_firm_names - existing_firm_names):
        db.session.add(Firm(name=firm_name))

    db.session.commit()


def ensure_firm_columns():
    inspector = inspect(db.engine)
    existing_columns = {
        column["name"] for column in inspector.get_columns("firms")
    }
    required_columns = {
        "max_team_members": "ALTER TABLE firms ADD COLUMN max_team_members INTEGER DEFAULT 10",
        "app_display_name": "ALTER TABLE firms ADD COLUMN app_display_name VARCHAR(200)",
        "app_logo_data": "ALTER TABLE firms ADD COLUMN app_logo_data TEXT",
        "gmail_sender_email": "ALTER TABLE firms ADD COLUMN gmail_sender_email VARCHAR(255)",
        "gmail_refresh_token": "ALTER TABLE firms ADD COLUMN gmail_refresh_token TEXT",
        "gmail_access_token": "ALTER TABLE firms ADD COLUMN gmail_access_token TEXT",
        "gmail_token_expiry": "ALTER TABLE firms ADD COLUMN gmail_token_expiry DATETIME",
        "gmail_scopes": "ALTER TABLE firms ADD COLUMN gmail_scopes TEXT",
        "gmail_connected_at": "ALTER TABLE firms ADD COLUMN gmail_connected_at DATETIME",
    }

    for column_name, ddl in required_columns.items():
        if column_name not in existing_columns:
            db.session.execute(text(ddl))

    db.session.execute(
        text(
            """
            UPDATE firms
            SET max_team_members = 10
            WHERE max_team_members IS NULL OR max_team_members < 1
            """
        )
    )
    db.session.execute(
        text(
            """
            UPDATE firms
            SET max_team_members = (
                SELECT CASE
                    WHEN COUNT(*) > firms.max_team_members THEN COUNT(*)
                    ELSE firms.max_team_members
                END
                FROM app_users
                WHERE app_users.firm_id = firms.id
            )
            WHERE EXISTS (
                SELECT 1 FROM app_users WHERE app_users.firm_id = firms.id
            )
            """
        )
    )
    db.session.commit()


def ensure_client_columns():
    inspector = inspect(db.engine)
    existing_columns = {
        column["name"] for column in inspector.get_columns("clients")
    }
    required_columns = {
        "firm_id": "ALTER TABLE clients ADD COLUMN firm_id INTEGER",
        "owner_username": "ALTER TABLE clients ADD COLUMN owner_username VARCHAR(120) DEFAULT 'admin'",
        "firm_name": "ALTER TABLE clients ADD COLUMN firm_name VARCHAR(200) DEFAULT 'Default Firm'",
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
    if "firm_name" in existing_columns or "firm_name" in required_columns:
        db.session.execute(
            text(
                "UPDATE clients "
                "SET firm_name = COALESCE(("
                "SELECT firm_name FROM app_users WHERE app_users.username = clients.owner_username"
                "), 'Default Firm') "
                "WHERE firm_name IS NULL OR firm_name = ''"
            )
        )
    if "firm_id" in existing_columns or "firm_id" in required_columns:
        db.session.execute(
            text(
                "UPDATE clients "
                "SET firm_id = COALESCE(("
                "SELECT id FROM firms WHERE firms.name = clients.firm_name"
                "), (SELECT id FROM firms WHERE firms.name = 'Default Firm')) "
                "WHERE firm_id IS NULL"
            )
        )

    db.session.commit()


def ensure_payment_columns():
    inspector = inspect(db.engine)
    existing_columns = {
        column["name"] for column in inspector.get_columns("payments")
    }
    required_columns = {
        "firm_id": "ALTER TABLE payments ADD COLUMN firm_id INTEGER",
        "owner_username": "ALTER TABLE payments ADD COLUMN owner_username VARCHAR(120) DEFAULT 'admin'",
        "firm_name": "ALTER TABLE payments ADD COLUMN firm_name VARCHAR(200) DEFAULT 'Default Firm'",
    }

    for column_name, ddl in required_columns.items():
        if column_name not in existing_columns:
            db.session.execute(text(ddl))

    db.session.execute(
        text(
            "UPDATE payments SET owner_username = 'admin' "
            "WHERE owner_username IS NULL OR owner_username = ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE payments "
            "SET firm_name = COALESCE(("
            "SELECT firm_name FROM app_users WHERE app_users.username = payments.owner_username"
            "), 'Default Firm') "
            "WHERE firm_name IS NULL OR firm_name = ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE payments "
            "SET firm_id = COALESCE(("
            "SELECT id FROM firms WHERE firms.name = payments.firm_name"
            "), (SELECT id FROM firms WHERE firms.name = 'Default Firm')) "
            "WHERE firm_id IS NULL"
        )
    )
    db.session.commit()


def ensure_app_user_columns():
    inspector = inspect(db.engine)
    existing_columns = {
        column["name"] for column in inspector.get_columns("app_users")
    }
    required_columns = {
        "email": "ALTER TABLE app_users ADD COLUMN email VARCHAR(255)",
        "full_name": "ALTER TABLE app_users ADD COLUMN full_name VARCHAR(255)",
        "firm_id": "ALTER TABLE app_users ADD COLUMN firm_id INTEGER",
        "firm_name": "ALTER TABLE app_users ADD COLUMN firm_name VARCHAR(200) DEFAULT 'Default Firm'",
        "role": "ALTER TABLE app_users ADD COLUMN role VARCHAR(50) DEFAULT 'firm_admin'",
    }

    for column_name, ddl in required_columns.items():
        if column_name not in existing_columns:
            db.session.execute(text(ddl))

    db.session.execute(
        text(
            "UPDATE app_users SET firm_name = 'Default Firm' "
            "WHERE firm_name IS NULL OR firm_name = ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE app_users SET role = CASE "
            "WHEN email = 'admin@default-firm.local' THEN 'platform_admin' "
            "WHEN is_admin = 1 THEN 'firm_admin' ELSE 'firm_member' END "
            "WHERE role IS NULL OR role = ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE app_users SET role = 'lawyer' "
            "WHERE role = 'firm_member'"
        )
    )
    db.session.execute(
        text(
            "UPDATE app_users SET full_name = username "
            "WHERE (full_name IS NULL OR full_name = '') AND username IS NOT NULL AND username != ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE app_users "
            "SET email = lower(replace(username, ' ', '.')) || '+' || "
            "lower(replace(firm_name, ' ', '.')) || '@legacy.local' "
            "WHERE email IS NULL OR email = ''"
        )
    )
    db.session.execute(
        text(
            "UPDATE app_users "
            "SET firm_id = COALESCE(("
            "SELECT id FROM firms WHERE firms.name = app_users.firm_name"
            "), (SELECT id FROM firms WHERE firms.name = 'Default Firm')) "
            "WHERE firm_id IS NULL"
        )
    )
    db.session.commit()


def ensure_app_user_indexes():
    if db.engine.dialect.name != "sqlite":
        return

    index_rows = db.session.execute(
        text("PRAGMA index_list('app_users')")
    ).fetchall()
    has_username_only_unique_index = False
    for index_row in index_rows:
        index_name = index_row[1]
        is_unique = bool(index_row[2])
        if not is_unique:
            continue
        indexed_columns = db.session.execute(
            text(f"PRAGMA index_info('{index_name}')")
        ).fetchall()
        column_names = [column_row[2] for column_row in indexed_columns]
        if column_names == ["username"]:
            has_username_only_unique_index = True
            break

    if has_username_only_unique_index:
        db.session.execute(text("ALTER TABLE app_users RENAME TO app_users_old"))
        db.session.execute(
            text(
                """
                CREATE TABLE app_users (
                    id INTEGER NOT NULL PRIMARY KEY,
                    username VARCHAR(120) NOT NULL,
                    email VARCHAR(255),
                    full_name VARCHAR(255),
                    firm_id INTEGER,
                    password_hash VARCHAR(255) NOT NULL,
                    firm_name VARCHAR(200) NOT NULL DEFAULT 'Default Firm',
                    role VARCHAR(50) NOT NULL DEFAULT 'firm_admin',
                    is_admin BOOLEAN NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    FOREIGN KEY(firm_id) REFERENCES firms (id)
                )
                """
            )
        )
        db.session.execute(
            text(
                """
                INSERT INTO app_users (
                    id, username, email, full_name, firm_id, password_hash, firm_name, role, is_admin, created_at, updated_at
                )
                SELECT
                    id,
                    username,
                    COALESCE(NULLIF(email, ''), lower(replace(username, ' ', '.')) || '+' || lower(replace(firm_name, ' ', '.')) || '@legacy.local'),
                    COALESCE(NULLIF(full_name, ''), username),
                    COALESCE(firm_id, (SELECT id FROM firms WHERE firms.name = COALESCE(NULLIF(app_users_old.firm_name, ''), 'Default Firm'))),
                    password_hash,
                    COALESCE(NULLIF(firm_name, ''), 'Default Firm'),
                    COALESCE(NULLIF(role, ''), CASE
                        WHEN email = 'admin@default-firm.local' THEN 'platform_admin'
                        WHEN is_admin = 1 THEN 'firm_admin'
                        ELSE 'firm_member'
                    END),
                    is_admin,
                    created_at,
                    updated_at
                FROM app_users_old
                """
            )
        )
        db.session.execute(text("DROP TABLE app_users_old"))
    db.session.execute(
        text("CREATE UNIQUE INDEX IF NOT EXISTS ix_app_users_firm_username ON app_users (firm_id, username)")
    )
    db.session.execute(
        text("CREATE UNIQUE INDEX IF NOT EXISTS ix_app_users_email ON app_users (email)")
    )
    db.session.commit()


def ensure_admin_user():
    default_firm = Firm.query.filter_by(name="Default Firm").first()
    admin_user = AppUser.query.filter_by(email="admin@default-firm.local").first()
    if not admin_user:
        admin_user = AppUser.query.filter_by(username="admin", firm_name="Default Firm").first()
    if admin_user:
        admin_user.firm_name = admin_user.firm_name or "Default Firm"
        admin_user.firm_id = admin_user.firm_id or (default_firm.id if default_firm else None)
        admin_user.role = admin_user.role or "firm_admin"
        admin_user.full_name = admin_user.full_name or "Admin"
        admin_user.email = admin_user.email or "admin@default-firm.local"
        admin_user.is_admin = True
        db.session.commit()
        return

    user = AppUser(
        username="admin",
        email="admin@default-firm.local",
        full_name="Admin",
        firm_id=default_firm.id if default_firm else None,
        firm_name="Default Firm",
        role="firm_admin",
        is_admin=True,
    )
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
        if "firms" in inspect(db.engine).get_table_names():
            ensure_firm_columns()
        ensure_firms()
        if "app_users" in inspect(db.engine).get_table_names():
            ensure_app_user_columns()
            ensure_app_user_indexes()
        ensure_admin_user()
        if "clients" in inspect(db.engine).get_table_names():
            ensure_client_columns()
        if "payments" in inspect(db.engine).get_table_names():
            ensure_payment_columns()

    @app.before_request
    def validate_active_user_session():
        if request.method == "OPTIONS":
            return None

        endpoint = request.endpoint or ""
        if endpoint in {
            "auth_bp.login",
            "auth_bp.master_login",
            "auth_bp.signup",
            "auth_bp.gmail_mailbox_callback",
            "static",
        }:
            return None

        username = get_request_username(default=None)
        firm_name = get_request_firm_name(default=None)
        user_email = (request.headers.get("X-User-Email") or request.args.get("email") or "").strip()
        if not username and not user_email:
            return None

        if user_email:
            user = AppUser.query.filter_by(email=user_email).first()
        elif username and "@" in username:
            user = AppUser.query.filter_by(email=username).first()
        elif firm_name:
            user = AppUser.query.filter_by(
                username=username,
                firm_name=firm_name,
            ).first()
        else:
            user = AppUser.query.filter_by(username=username).first()
        if user is None:
            return jsonify({
                "error": "This account no longer exists. Please contact your firm admin.",
            }), 401
        if firm_name and not user.is_platform_admin and user.firm_name != firm_name:
            return jsonify({
                "error": "This request does not belong to your firm workspace.",
            }), 403
        if (
            not user.is_platform_admin
            and not user.can_manage_billing
            and firm_is_over_limit(user)
        ):
            return jsonify({
                "error": firm_over_limit_message(user),
            }), 403

    # Register blueprints
    app.register_blueprint(email_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(client_bp)  # NEW
    app.register_blueprint(payment_bp)
    app.register_blueprint(document_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(ai_bp)
    app.register_blueprint(ecourts_bp)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
