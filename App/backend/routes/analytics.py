# App/backend/routes/analytics.py
from datetime import datetime
from fastapi import APIRouter, Query

from database.collections import get_collections

router = APIRouter(prefix="/analytics", tags=["analytics"])


def _safe_dt(value) -> datetime | None:
    if not value:
      return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).replace(tzinfo=None)
    except Exception:
        return None


def _weekday_label(index: int) -> str:
    labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    return labels[index] if 0 <= index < 7 else "N/A"


@router.get("/overview")
async def analytics_overview(user_id: int = Query(...)):
    collections = get_collections()
    sos_events_col = collections["sos_events"]
    threat_reports_col = collections["threat_reports"]
    audio_analytics_col = collections["audio_session_analytics"]
    ai_suggestions_col = collections["ai_suggestions"]

    sos_events = await sos_events_col.find({"user_id": user_id}, {"_id": 0}).sort("created_at", -1).to_list(length=300)
    threat_reports = await threat_reports_col.find({"reported_by": user_id}, {"_id": 0}).to_list(length=300)
    audio_sessions = await audio_analytics_col.find(
        {"$or": [{"user_id": user_id}, {"user_id": None}]}, {"_id": 0}
    ).sort("closed_at", -1).to_list(length=500)

    high_threat_reports = sum(1 for t in threat_reports if str(t.get("threat_level", "")).lower() == "high")
    medium_low_reports = sum(1 for t in threat_reports if str(t.get("threat_level", "")).lower() in {"medium", "low"})
    sos_count = len(sos_events)

    high_alert_count = high_threat_reports + sos_count
    soft_alert_count = medium_low_reports
    false_alert_count = sum(1 for s in audio_sessions if float(s.get("avg_audio_score", 0.0) or 0.0) < 0.35)

    alerts_history = []
    for s in sos_events[:20]:
        alerts_history.append(
            {
                "time": s.get("created_at", ""),
                "location": s.get("location", "Unknown"),
                "threatType": f"SOS ({s.get('trigger_type', 'automatic')})",
            }
        )
    for t in threat_reports[:20]:
        dt = _safe_dt(t.get("timestamp"))
        alerts_history.append(
            {
                "time": dt.isoformat() if dt else "",
                "location": t.get("location", "Unknown"),
                "threatType": f"Threat: {str(t.get('threat_level', 'unknown')).capitalize()}",
            }
        )
    alerts_history = sorted(alerts_history, key=lambda x: x.get("time", ""), reverse=True)[:20]

    bins = {"0-20": 0, "21-40": 0, "41-60": 0, "61-80": 0, "81-100": 0}
    for s in audio_sessions:
        score_pct = int(round(float(s.get("avg_audio_score", 0.0) or 0.0) * 100))
        if score_pct <= 20:
            bins["0-20"] += 1
        elif score_pct <= 40:
            bins["21-40"] += 1
        elif score_pct <= 60:
            bins["41-60"] += 1
        elif score_pct <= 80:
            bins["61-80"] += 1
        else:
            bins["81-100"] += 1

    threat_distribution = [{"label": k, "value": v} for k, v in bins.items()]

    hourly_counts = {"6 AM": 0, "9 AM": 0, "1 PM": 0, "6 PM": 0, "9 PM": 0}
    for s in sos_events:
        dt = _safe_dt(s.get("created_at"))
        if not dt:
            continue
        h = dt.hour
        if 5 <= h < 8:
            hourly_counts["6 AM"] += 1
        elif 8 <= h < 11:
            hourly_counts["9 AM"] += 1
        elif 12 <= h < 15:
            hourly_counts["1 PM"] += 1
        elif 17 <= h < 20:
            hourly_counts["6 PM"] += 1
        elif 20 <= h <= 23:
            hourly_counts["9 PM"] += 1

    hourly_pattern = [{"slot": k, "count": v} for k, v in hourly_counts.items()]

    weekday_counts = {"Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0, "Fri": 0, "Sat": 0, "Sun": 0}
    for s in sos_events:
        dt = _safe_dt(s.get("created_at"))
        if not dt:
            continue
        weekday_counts[_weekday_label(dt.weekday())] += 1
    daily_pattern = [{"slot": k, "count": v} for k, v in weekday_counts.items()]

    week_counts = {"W1": 0, "W2": 0, "W3": 0, "W4": 0}
    for s in sos_events:
        dt = _safe_dt(s.get("created_at"))
        if not dt:
            continue
        week_idx = min(4, max(1, ((dt.day - 1) // 7) + 1))
        week_counts[f"W{week_idx}"] += 1
    weekly_pattern = [{"slot": k, "count": v} for k, v in week_counts.items()]

    avg_audio_score = round(
        sum(float(s.get("avg_audio_score", 0.0) or 0.0) for s in audio_sessions) / len(audio_sessions),
        2,
    ) if audio_sessions else 0.0

    ai_doc = await ai_suggestions_col.find_one({"user_id": user_id}, {"_id": 0}, sort=[("created_at", -1)])
    ai_recommendations = (ai_doc or {}).get("suggestions", [])

    return {
        "alertsHistory": alerts_history,
        "threatDistribution": threat_distribution,
        "alertCategories": [
            {"label": "High Threat Alerts", "count": high_alert_count},
            {"label": "Soft Alerts", "count": soft_alert_count},
            {"label": "False Alerts", "count": false_alert_count},
        ],
        "hourlyPattern": hourly_pattern,
        "dailyPattern": daily_pattern,
        "weeklyPattern": weekly_pattern,
        "averageAudioScore": avg_audio_score,
        "averageAudioSummary": "Computed from audio-websocket sessions for this user.",
        "aiRecommendations": ai_recommendations,
    }


@router.get("/stats/{stat_id}")
async def stat_detail(stat_id: str, user_id: int = Query(...)):
    overview = await analytics_overview(user_id=user_id)

    high = next((x.get("count", 0) for x in overview["alertCategories"] if x.get("label") == "High Threat Alerts"), 0)
    soft = next((x.get("count", 0) for x in overview["alertCategories"] if x.get("label") == "Soft Alerts"), 0)
    false = next((x.get("count", 0) for x in overview["alertCategories"] if x.get("label") == "False Alerts"), 0)

    mapping = {
        "threat_prevention": {
            "id": "threat_prevention",
            "title": "Threat Prevention",
            "value": f"{max(0, 100 - min(99, false * 3))}%",
            "trend": 0,
            "color": "#22C55E",
            "subtitle": "Derived from false alert ratio",
            "details": "Dynamic estimate based on low-confidence audio sessions and alert history.",
        },
        "response_time": {
            "id": "response_time",
            "title": "Response Time",
            "value": "~13s",
            "trend": 0,
            "color": "#3B82F6",
            "subtitle": "Automatic SOS countdown latency",
            "details": "Automatic SOS now uses backend countdown and dispatch flow.",
        },
        "false_alarms": {
            "id": "false_alarms",
            "title": "False Alarms",
            "value": str(false),
            "trend": 0,
            "color": "#F59E0B",
            "subtitle": "Low-confidence sessions",
            "details": "Count of sessions with lower average audio confidence.",
        },
        "safe_coverage": {
            "id": "safe_coverage",
            "title": "Safe Coverage",
            "value": str(max(0, soft - high)),
            "trend": 0,
            "color": "#A855F7",
            "subtitle": "Soft vs high alert differential",
            "details": "Higher value means more low/medium events than critical alerts.",
        },
    }

    return mapping.get(
        stat_id,
        {
            "id": stat_id,
            "title": "Unknown Stat",
            "value": "--",
            "trend": 0,
            "color": "#64748B",
            "subtitle": "No info available",
            "details": "No details found for this stat ID.",
        },
    )
