import requests
from typing import Dict, List

from config.settings import FCM_SERVER_KEY, SMS_PROVIDER_URL, SMS_PROVIDER_API_KEY


def send_fcm_notifications(tokens: List[str], title: str, body: str, data: Dict[str, str]) -> Dict[str, int]:
    valid_tokens = [token for token in tokens if isinstance(token, str) and token.strip()]
    if not valid_tokens or not FCM_SERVER_KEY:
        return {"sent": 0, "failed": len(valid_tokens)}

    sent = 0
    failed = 0
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"key={FCM_SERVER_KEY}",
    }

    for token in valid_tokens:
        payload = {
            "to": token,
            "notification": {
                "title": title,
                "body": body,
            },
            "data": data,
            "priority": "high",
        }

        try:
            response = requests.post(
                "https://fcm.googleapis.com/fcm/send",
                headers=headers,
                json=payload,
                timeout=8,
            )
            if response.status_code == 200:
                sent += 1
            else:
                failed += 1
        except Exception:
            failed += 1

    return {"sent": sent, "failed": failed}


def send_sms_fallback(phone: str, message: str) -> bool:
    if not phone or not SMS_PROVIDER_URL or not SMS_PROVIDER_API_KEY:
        return False

    try:
        response = requests.post(
            SMS_PROVIDER_URL,
            json={
                "to": phone,
                "message": message,
            },
            headers={
                "Authorization": f"Bearer {SMS_PROVIDER_API_KEY}",
                "Content-Type": "application/json",
            },
            timeout=8,
        )
        return 200 <= response.status_code < 300
    except Exception:
        return False
