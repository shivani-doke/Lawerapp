import json
from pathlib import Path

from flask import Blueprint, current_app, jsonify, request
import requests


ecourts_bp = Blueprint("ecourts_bp", __name__, url_prefix="/ecourts")

ECOURTS_SEARCH_URL = "https://webapi.ecourtsindia.com/api/partner/search"
ECOURTS_CASE_DETAIL_URL = "https://webapi.ecourtsindia.com/api/partner/case"
ALLOWED_QUERY_PARAMS = {
    "query",
    "advocates",
    "judges",
    "petitioners",
    "respondents",
    "litigants",
    "courtCodes",
    "caseType",
    "caseStatus",
    "filingDateFrom",
    "filingDateTo",
    "registrationDateFrom",
    "registrationDateTo",
    "decisionDateFrom",
    "decisionDateTo",
    "page",
    "pageSize",
}


def _clean_param(value):
    text = (value or "").strip()
    return text if text else None


def _normalize_case(item, enum_lookup):
    case_type = (item.get("caseType") or "").strip()
    case_status = (item.get("caseStatus") or "").strip()
    court_code = (item.get("courtCode") or "").strip()
    judicial_section = (item.get("judicialSection") or "").strip()

    return {
        "cnr": item.get("cnr"),
        "caseType": case_type,
        "caseTypeLabel": (
            enum_lookup.get("caseType", {}).get(case_type) or case_type or "Unknown"
        ),
        "caseStatus": case_status,
        "caseStatusLabel": (
            enum_lookup.get("caseStatus", {}).get(case_status) or case_status or "Unknown"
        ),
        "filingDate": item.get("filingDate"),
        "nextHearingDate": item.get("nextHearingDate"),
        "registrationNumber": item.get("registrationNumber"),
        "registrationDate": item.get("registrationDate"),
        "decisionDate": item.get("decisionDate"),
        "petitioners": item.get("petitioners") or [],
        "respondents": item.get("respondents") or [],
        "petitionerAdvocates": item.get("petitionerAdvocates") or [],
        "judges": item.get("judges") or [],
        "actsAndSections": item.get("actsAndSections") or [],
        "aiKeywords": item.get("aiKeywords") or [],
        "courtCode": court_code,
        "courtCodeLabel": (
            enum_lookup.get("courtCode", {}).get(court_code) or court_code or "Unknown"
        ),
        "judicialSection": judicial_section,
        "judicialSectionLabel": (
            enum_lookup.get("judicialSection", {}).get(judicial_section)
            or judicial_section
            or "Unknown"
        ),
        "caseCategory": item.get("caseCategory"),
        "caseCategoryFacetPath": item.get("caseCategoryFacetPath") or [],
        "benchType": item.get("benchType"),
    }


def _api_headers():
    api_key = current_app.config.get("ECOURTS_API_KEY")
    if not api_key:
        return None
    return {"Authorization": f"Bearer {api_key}"}


def _build_document(title, document_type, confidence, reasons):
    return {
        "title": title,
        "documentType": document_type,
        "confidence": confidence,
        "reasons": reasons,
    }


def _contains_any(text, keywords):
    haystack = (text or "").lower()
    return any(keyword in haystack for keyword in keywords)


def _first_non_empty(*values):
    for value in values:
        if isinstance(value, str):
            text = value.strip()
            if text:
                return text
        elif value:
            return value
    return None


def _derive_case_ai_analysis(case_ai_analysis, files):
    if case_ai_analysis:
        return case_ai_analysis

    for file_item in files:
        ai_analysis = file_item.get("aiAnalysis") or {}
        foundational = ai_analysis.get("foundational_metadata") or {}
        deep_context = ai_analysis.get("deep_legal_substance_context") or {}
        insights = ai_analysis.get("intelligent_insights_analytics") or {}

        impact = insights.get("order_significance_and_impact_assessment") or {}
        core_legal = deep_context.get("core_legal_content_analysis") or {}
        reasoning = deep_context.get("arguments_and_reasoning_analysis") or {}
        core_identifiers = foundational.get("core_case_identifiers") or {}
        procedural = foundational.get("procedural_details_from_order") or {}

        summary = _first_non_empty(
            impact.get("ai_generated_executive_summary"),
            impact.get("plain_language_summary_for_litigants_outcome_focused"),
            reasoning.get("court_reasoning_for_decision"),
        )

        case_type = _first_non_empty(
            core_identifiers.get("case_type"),
            procedural.get("order_nature"),
        )

        key_issues = []
        statutes = core_legal.get("statutes_cited_and_applied") or []
        for statute in statutes:
            if not isinstance(statute, dict):
                continue
            act_name = _first_non_empty(statute.get("act_name"))
            section = _first_non_empty(statute.get("section_article_rule"))
            if act_name and section:
                key_issues.append(f"{act_name} - {section}")
            elif act_name:
                key_issues.append(act_name)

        ratio = reasoning.get("ratio_decidendi_extracted") or {}
        ratio_statement = _first_non_empty(ratio.get("statement"))
        if ratio_statement:
            key_issues.append(ratio_statement)

        directions = procedural.get("specific_directions_given_by_court") or []
        for direction in directions:
            if isinstance(direction, str) and direction.strip():
                key_issues.append(direction.strip())

        deduped_issues = []
        seen = set()
        for issue in key_issues:
            if issue in seen:
                continue
            seen.add(issue)
            deduped_issues.append(issue)

        complexity = "Not available"
        confidence = ratio.get("confidence_score")
        if isinstance(confidence, (int, float)):
            if confidence >= 8:
                complexity = "High"
            elif confidence >= 5:
                complexity = "Medium"
            else:
                complexity = "Low"

        derived = {
            "caseSummary": summary,
            "caseType": case_type,
            "complexity": complexity,
            "keyIssues": deduped_issues,
        }

        if any(
            [
                derived["caseSummary"],
                derived["caseType"],
                derived["keyIssues"],
                derived["complexity"] != "Not available",
            ]
        ):
            return derived

    return {}


def _recommend_documents(case_detail):
    case_data = case_detail.get("courtCaseData") or {}
    case_ai = case_detail.get("caseAiAnalysis") or {}

    purpose = (case_data.get("purpose") or "").strip()
    case_type = (case_data.get("caseType") or "").strip()
    case_type_raw = (case_data.get("caseTypeRaw") or "").strip()
    judicial_section = (
        case_data.get("judicialSectionRaw") or case_data.get("judicialSection") or ""
    ).strip()
    acts = (case_data.get("actsAndSections") or "").strip()
    summary = (case_ai.get("caseSummary") or "").strip()
    ai_type = (case_ai.get("caseType") or "").strip()
    key_issues = " ".join(case_ai.get("keyIssues") or [])
    raw_category = case_data.get("caseCategoryFacetPath") or ""
    if isinstance(raw_category, list):
        category = " ".join(str(item) for item in raw_category)
    else:
        category = str(raw_category).strip()

    combined_text = " ".join(
        [
            purpose,
            case_type,
            case_type_raw,
            judicial_section,
            acts,
            summary,
            ai_type,
            key_issues,
            category,
        ]
    )

    suggestions = []
    seen_titles = set()

    def add(title, document_type, confidence, reasons):
        if title in seen_titles:
            return
        seen_titles.add(title)
        suggestions.append(
            _build_document(title, document_type, confidence, reasons)
        )

    add(
        "Affidavit",
        "affidavit",
        "High",
        [
            "Affidavits are commonly useful across active litigation for sworn facts and supporting filings.",
            "This case already contains structured hearing and party details that can support affidavit drafting.",
        ],
    )

    if _contains_any(
        combined_text,
        ["contract", "commercial", "specific performance", "vendor", "service"],
    ):
        add(
            "Settlement Agreement",
            "settlement_agreement",
            "High",
            [
                "The case signals a commercial or contract-oriented dispute.",
                "Settlement drafts are often useful when parties may negotiate resolution outside court.",
            ],
        )
        add(
            "Memorandum Of Understanding",
            "memorandum_of_understanding",
            "Medium",
            [
                "An MOU can help record interim commercial terms or settlement discussions.",
            ],
        )
        add(
            "Service Agreement",
            "service_agreement",
            "Medium",
            [
                "If the dispute concerns performance obligations, a service agreement can help rebuild or clarify contractual terms.",
            ],
        )
        add(
            "Vendor Agreement",
            "vendor_agreement",
            "Medium",
            [
                "Vendor agreements are relevant when the dispute concerns supply, delivery, or business obligations.",
            ],
        )

    if _contains_any(combined_text, ["bail", "criminal", "fir", "accused"]):
        add(
            "Bail Application",
            "bail_application",
            "High",
            ["The case signals a criminal or bail-related matter."],
        )

    if _contains_any(combined_text, ["divorce", "marriage", "matrimonial"]):
        add(
            "Divorce Paper",
            "divorce_paper",
            "High",
            ["The matter appears matrimonial in nature."],
        )
        add(
            "Settlement Agreement",
            "settlement_agreement",
            "High",
            ["Matrimonial matters often benefit from structured settlement terms."],
        )

    if _contains_any(combined_text, ["custody", "child", "guardian", "adoption"]):
        add(
            "Child Custody Agreement",
            "child_custody_agreement",
            "High",
            ["The case detail suggests child or guardianship-related issues."],
        )
        add(
            "Adoption Papers",
            "adoption_papers",
            "Medium",
            [
                "Adoption documents are relevant where family-law issues overlap with guardianship or adoption.",
            ],
        )

    if _contains_any(
        combined_text,
        ["property", "sale deed", "partition", "gift", "mortgage", "immovable", "real estate"],
    ):
        add(
            "Sale Deed",
            "sale_deed",
            "Medium",
            ["The matter appears connected to property transfer or title issues."],
        )
        add(
            "Partition Deed",
            "partition_deed",
            "Medium",
            [
                "Partition-related drafting is useful where ownership shares or division of property are in dispute.",
            ],
        )
        add(
            "Gift Deed",
            "gift_deed",
            "Low",
            ["Gift deed drafting can help where ownership transfer is part of the dispute context."],
        )
        add(
            "Mortgage Deed",
            "mortgage_deed",
            "Low",
            [
                "Mortgage documentation can be relevant when property security or encumbrance is involved.",
            ],
        )
        add(
            "Power Of Attorney",
            "power_of_attorney",
            "Medium",
            [
                "Property and title matters often require authority documents for representation or execution.",
            ],
        )

    if _contains_any(combined_text, ["employment", "employee", "salary", "termination", "workman"]):
        add(
            "Employment Contract",
            "employment_contract",
            "High",
            ["The case appears employment-related."],
        )
        add(
            "Offer Letter",
            "offer_letter",
            "Medium",
            [
                "Offer letter drafting can support disputes around hiring terms and employment promises.",
            ],
        )

    if _contains_any(
        combined_text,
        ["partnership", "joint venture", "assignment", "license", "licensing", "indemnity", "nda", "confidential"],
    ):
        add(
            "Partnership Deed",
            "partnership_deed",
            "Medium",
            ["The matter indicates a business relationship dispute."],
        )
        add(
            "Joint Venture Agreement",
            "joint_venture_agreement",
            "Medium",
            ["Joint venture terms may be relevant where parties collaborated commercially."],
        )
        add(
            "Licensing Agreement",
            "licensing_agreement",
            "Medium",
            ["Licensing terms may matter where rights, permissions, or commercial use are disputed."],
        )
        add(
            "Assignment Agreement",
            "assignment_agreement",
            "Medium",
            ["Assignment drafting can help formalize transfer of rights or obligations."],
        )
        add(
            "Indemnity Agreement",
            "indemnity_agreement",
            "Low",
            ["Indemnity clauses are often relevant in commercial risk allocation disputes."],
        )
        add(
            "Non Disclosure Agreement",
            "non_disclosure_agreement",
            "Low",
            ["Confidentiality issues can make NDA drafting useful in commercial matters."],
        )

    if _contains_any(
        combined_text,
        ["trademark", "copyright", "patent", "intellectual property", "ip"],
    ):
        add(
            "Trademark Application",
            "trademark_application",
            "High",
            ["The matter appears related to brand or mark protection."],
        )
        add(
            "Copyright Agreement",
            "copyright_agreement",
            "Medium",
            ["Copyright documentation can help define authorship and ownership rights."],
        )
        add(
            "Patent Filing Documents",
            "patent_filing_documents",
            "Medium",
            ["Patent filings may be relevant if the dispute involves inventions or technical IP."],
        )

    if _contains_any(purpose, ["argument", "hearing", "reply", "rejoinder", "evidence"]) or (
        (case_data.get("hearingCount") or 0) > 0
    ):
        add(
            "Affidavit",
            "affidavit",
            "High",
            [
                "The case is active at a hearing-oriented stage where sworn factual support is commonly useful.",
            ],
        )

    return suggestions[:6]


def _normalize_case_detail(payload):
    data = payload.get("data") or {}
    case_data = data.get("courtCaseData") or {}
    entity_info = data.get("entityInfo") or {}
    files = ((data.get("files") or {}).get("files")) or []
    descriptions = data.get("descriptions") or {}
    enum_lookup = descriptions.get("enumLookup") or {}
    case_ai_analysis = _derive_case_ai_analysis(
        data.get("caseAiAnalysis") or {},
        files,
    )

    normalized = {
        "courtCaseData": {
            "cnr": case_data.get("cnr"),
            "caseNumber": case_data.get("caseNumber"),
            "caseType": case_data.get("caseType"),
            "caseTypeRaw": case_data.get("caseTypeRaw"),
            "caseTypeLabel": (
                enum_lookup.get("caseType", {}).get(case_data.get("caseType"))
                or case_data.get("caseTypeRaw")
                or case_data.get("caseType")
            ),
            "caseStatus": case_data.get("caseStatus"),
            "caseStatusLabel": (
                enum_lookup.get("caseStatus", {}).get(case_data.get("caseStatus"))
                or case_data.get("caseStatus")
            ),
            "filingDate": case_data.get("filingDate"),
            "registrationDate": case_data.get("registrationDate"),
            "firstHearingDate": case_data.get("firstHearingDate"),
            "nextHearingDate": case_data.get("nextHearingDate"),
            "lastHearingDate": case_data.get("lastHearingDate"),
            "decisionDate": case_data.get("decisionDate"),
            "caseDurationDays": case_data.get("caseDurationDays"),
            "filingToFirstHearingDays": case_data.get("filingToFirstHearingDays"),
            "judges": case_data.get("judges") or [],
            "petitioners": case_data.get("petitioners") or [],
            "petitionerAdvocates": case_data.get("petitionerAdvocates") or [],
            "respondents": case_data.get("respondents") or [],
            "respondentAdvocates": case_data.get("respondentAdvocates") or [],
            "actsAndSections": case_data.get("actsAndSections"),
            "caseTypeSub": case_data.get("caseTypeSub"),
            "courtName": case_data.get("courtName"),
            "state": case_data.get("state"),
            "district": case_data.get("district"),
            "courtNo": case_data.get("courtNo"),
            "benchName": case_data.get("benchName"),
            "purpose": case_data.get("purpose"),
            "stageOfCase": case_data.get("stageOfCase"),
            "stageOfCaseRaw": case_data.get("stageOfCaseRaw"),
            "judicialSection": case_data.get("judicialSection"),
            "judicialSectionRaw": case_data.get("judicialSectionRaw"),
            "cnrCourtCode": case_data.get("cnrCourtCode"),
            "courtComplexCode": case_data.get("courtComplexCode"),
            "filingNumber": case_data.get("filingNumber"),
            "registrationNumber": case_data.get("registrationNumber"),
            "caseCategoryFacetPath": case_data.get("caseCategoryFacetPath"),
            "historyOfCaseHearings": case_data.get("historyOfCaseHearings") or [],
            "hasOrders": case_data.get("hasOrders"),
            "hasJudgments": case_data.get("hasJudgments"),
            "orderCount": case_data.get("orderCount"),
            "interimOrderCount": case_data.get("interimOrderCount"),
            "judgmentCount": case_data.get("judgmentCount"),
            "hearingCount": case_data.get("hearingCount"),
            "iaCount": case_data.get("iaCount"),
        },
        "entityInfo": {
            "cnr": entity_info.get("cnr"),
            "nextDateOfHearing": entity_info.get("nextDateOfHearing"),
            "lastDateOfHearing": entity_info.get("lastDateOfHearing"),
            "dateCreated": entity_info.get("dateCreated"),
            "dateModified": entity_info.get("dateModified"),
        },
        "files": [
            {
                "pdfFile": file_item.get("pdfFile"),
                "markdownFile": file_item.get("markdownFile"),
                "markdownContent": file_item.get("markdownContent"),
                "aiAnalysis": file_item.get("aiAnalysis") or {},
            }
            for file_item in files
        ],
        "caseAiAnalysis": case_ai_analysis,
        "requestId": (payload.get("meta") or {}).get("request_id"),
    }
    normalized["recommendedDocuments"] = _recommend_documents(normalized)
    return normalized


@ecourts_bp.route("/cases-by-advocate", methods=["GET"])
def cases_by_advocate():
    headers = _api_headers()
    if not headers:
        return jsonify({"error": "eCourts API key is not configured on the server."}), 500

    advocates = _clean_param(request.args.get("advocates"))
    if not advocates:
        return jsonify({"error": "The advocates parameter is required."}), 400

    upstream_params = {}
    for key in ALLOWED_QUERY_PARAMS:
        value = _clean_param(request.args.get(key))
        if value:
            upstream_params[key] = value

    upstream_params.setdefault("page", "1")
    upstream_params.setdefault("pageSize", "20")

    try:
        response = requests.get(
            ECOURTS_SEARCH_URL,
            params=upstream_params,
            headers=headers,
            timeout=20,
        )
    except requests.Timeout:
        return jsonify({"error": "eCourts search timed out. Please try again."}), 504
    except requests.RequestException as exc:
        return jsonify({"error": f"Unable to reach eCourts API: {exc}"}), 502

    try:
        payload = response.json()
    except ValueError:
        return jsonify({"error": "eCourts API returned an invalid response."}), 502

    if response.status_code >= 400:
        return (
            jsonify(
                {
                    "error": payload.get("error")
                    or payload.get("message")
                    or "eCourts API request failed.",
                    "statusCode": response.status_code,
                }
            ),
            response.status_code,
        )

    data = payload.get("data") or {}
    enum_lookup = ((data.get("enumDescriptions") or {}).get("enumLookup")) or {}
    results = data.get("results") or []

    normalized_results = [_normalize_case(item, enum_lookup) for item in results]

    return jsonify(
        {
            "results": normalized_results,
            "pagination": {
                "totalHits": data.get("totalHits", 0),
                "page": data.get("page", 1),
                "pageSize": data.get("pageSize", len(normalized_results)),
                "totalPages": data.get("totalPages", 1),
                "hasNextPage": data.get("hasNextPage", False),
                "hasPreviousPage": data.get("hasPreviousPage", False),
            },
            "facets": data.get("facets") or {},
            "activeFilters": data.get("activeFilters") or [],
            "query": data.get("query"),
            "processingTimeMs": data.get("processingTimeMs"),
            "requestId": (payload.get("meta") or {}).get("request_id"),
        }
    )


@ecourts_bp.route("/case/<cnr>", methods=["GET"])
def case_by_cnr(cnr):
    headers = _api_headers()
    if not headers:
        return jsonify({"error": "eCourts API key is not configured on the server."}), 500

    normalized_cnr = _clean_param(cnr)
    if not normalized_cnr:
        return jsonify({"error": "CNR is required."}), 400

    debug_dir = Path(current_app.root_path) / "debug"
    debug_dir.mkdir(parents=True, exist_ok=True)
    debug_file = debug_dir / f"ecourts_case_{normalized_cnr}.json"

    if debug_file.exists():
        try:
            payload = json.loads(debug_file.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            return jsonify({"error": f"Unable to read cached case file: {exc}"}), 500
        return jsonify(_normalize_case_detail(payload))

    try:
        response = requests.get(
            f"{ECOURTS_CASE_DETAIL_URL}/{normalized_cnr}",
            headers=headers,
            timeout=20,
        )
    except requests.Timeout:
        return jsonify({"error": "eCourts case detail timed out. Please try again."}), 504
    except requests.RequestException as exc:
        return jsonify({"error": f"Unable to reach eCourts API: {exc}"}), 502

    try:
        payload = response.json()
    except ValueError:
        return jsonify({"error": "eCourts API returned an invalid response."}), 502

    debug_file.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    if response.status_code >= 400:
        return (
            jsonify(
                {
                    "error": payload.get("error")
                    or payload.get("message")
                    or "eCourts API request failed.",
                    "statusCode": response.status_code,
                }
            ),
            response.status_code,
        )

    return jsonify(_normalize_case_detail(payload))
