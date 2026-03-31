import json
from copy import deepcopy
from pathlib import Path


FIELDS_CONFIG_DIR = Path(__file__).resolve().parent / "document_fields_configs"
DEFAULT_FIELDS_FILE = FIELDS_CONFIG_DIR / "default.json"


def _safe_load_config(json_path):
    if not json_path.exists():
        return None

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return None

    return data


def _normalize_subtypes(raw_subtypes):
    if not isinstance(raw_subtypes, list):
        return []

    normalized = []
    for item in raw_subtypes:
        if not isinstance(item, dict):
            continue
        subtype_id = str(item.get("id", "")).strip()
        label = str(item.get("label", subtype_id)).strip()
        if subtype_id:
            normalized.append({"id": subtype_id, "label": label or subtype_id})
    return normalized


def _extract_fields_from_config(config_data, subtype=None):
    # Legacy format: plain list of fields
    if isinstance(config_data, list):
        return deepcopy(config_data)

    # Variant format:
    # {
    #   "base_fields": [...],
    #   "subtypes": [{"id":"..." ,"label":"..."}],
    #   "variants": {"subtype_id": [...]}
    # }
    if isinstance(config_data, dict):
        base_fields = config_data.get("base_fields", [])
        variants = config_data.get("variants", {})
        subtypes = _normalize_subtypes(config_data.get("subtypes", []))

        result = []
        if isinstance(base_fields, list):
            result.extend(base_fields)

        subtype_key = (subtype or "").strip()
        if not subtype_key and subtypes:
            subtype_key = subtypes[0]["id"]

        if isinstance(variants, dict) and subtype_key in variants:
            variant_fields = variants.get(subtype_key)
            if isinstance(variant_fields, list):
                result.extend(variant_fields)

        return deepcopy(result)

    return []


def get_subtypes_for_document_type(document_type):
    normalized_document_type = (document_type or "").strip().lower()
    config_file = FIELDS_CONFIG_DIR / f"{normalized_document_type}.json"
    config_data = _safe_load_config(config_file)
    if not isinstance(config_data, dict):
        return []
    return _normalize_subtypes(config_data.get("subtypes", []))


def get_fields_for_document_type(document_type, subtype=None):
    normalized_document_type = (document_type or "").strip().lower()
    config_file = FIELDS_CONFIG_DIR / f"{normalized_document_type}.json"
    config_data = _safe_load_config(config_file)

    fields = _extract_fields_from_config(config_data, subtype=subtype)
    if not fields:
        default_config = _safe_load_config(DEFAULT_FIELDS_FILE)
        fields = _extract_fields_from_config(default_config)

    return deepcopy(fields)
