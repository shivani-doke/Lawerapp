from flask import request


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
