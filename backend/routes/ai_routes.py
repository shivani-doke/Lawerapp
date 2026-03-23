# backend/routes/ai_routes.py

import requests
from flask import Blueprint, request, jsonify
from config import Config

ai_bp = Blueprint("ai_bp", __name__)

@ai_bp.route("/legal-ai", methods=["POST"])
def legal_ai():
    try:
        user_message = request.json.get("message")

        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={Config.GEMINI_API_KEY}"

        payload = {
            "system_instruction": {
                "parts": [
                    {
                        "text": "You are a specialized Indian Legal Assistant. "
                                "Answer only legal questions. "
                                "When possible, base your answers on Indian legal news and case law. "
                                "Prefer referencing these sources: barandbench.com, verdictum.in, scconline.com, and livemint.com. "
                                "If relevant, mention the source name."
                    }
                ]
            },
            "contents": [
                {
                    "parts": [
                        {"text": user_message}
                    ]
                }
            ]
        }

        response = requests.post(url, json=payload)
        data = response.json()

        ai_reply = data["candidates"][0]["content"]["parts"][0]["text"]

        return jsonify({"reply": ai_reply})

    except Exception as e:
        return jsonify({"error": str(e)}), 500