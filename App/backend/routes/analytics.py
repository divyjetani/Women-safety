from fastapi import APIRouter

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/overview")
async def analytics_overview():
    return {
        "weeklyTrends": [
            {"day": "Mon", "score": 84},
            {"day": "Tue", "score": 78},
            {"day": "Wed", "score": 90},
            {"day": "Thu", "score": 66},
            {"day": "Fri", "score": 87},
            {"day": "Sat", "score": 73},
            {"day": "Sun", "score": 93},
        ],
        "stats": [
            {
                "id": "threat_prevention",
                "title": "Threat Prevention",
                "value": "94%",
                "trend": 12,
                "color": "#22C55E",
                "subtitle": "Protection success rate",
                "details": "Threat prevention measures worked successfully in 94% of cases.",
            },
            {
                "id": "response_time",
                "title": "Response Time",
                "value": "2.4s",
                "trend": -5,
                "color": "#3B82F6",
                "subtitle": "Avg system reaction time",
                "details": "Response time measures how quickly the system triggers actions.",
            },
            {
                "id": "false_alarms",
                "title": "False Alarms",
                "value": "3%",
                "trend": -8,
                "color": "#F59E0B",
                "subtitle": "Unnecessary triggers",
                "details": "False alarms happen when system triggers without real danger.",
            },
            {
                "id": "safe_coverage",
                "title": "Safe Coverage",
                "value": "86%",
                "trend": 15,
                "color": "#A855F7",
                "subtitle": "Area safety availability",
                "details": "Percentage of area mapped with safe points.",
            },
        ],
        "peakHours": [
            {"time": "6 PM - 9 PM", "percentage": 0.65, "color": "#EF4444"},
            {"time": "9 PM - 12 AM", "percentage": 0.45, "color": "#F59E0B"},
            {"time": "12 PM - 3 PM", "percentage": 0.25, "color": "#22C55E"},
            {"time": "3 AM - 6 AM", "percentage": 0.15, "color": "#22C55E"},
        ],
        "safetyTips": [
            {
                "icon": "location",
                "title": "Live Location Sharing",
                "description": "Share your live location with trusted contacts.",
            },
            {
                "icon": "group",
                "title": "Use the Buddy System",
                "description": "Avoid traveling alone at night.",
            },
            {
                "icon": "light",
                "title": "Stay in Well-lit Areas",
                "description": "Avoid isolated shortcuts.",
            },
            {
                "icon": "battery",
                "title": "Keep Phone Charged",
                "description": "Carry a power bank.",
            },
        ],
    }


@router.get("/stats/{stat_id}")
async def stat_detail(stat_id: str):
    mapping = {
        "threat_prevention": {
            "id": "threat_prevention",
            "title": "Threat Prevention",
            "value": "94%",
            "trend": 12,
            "color": "#22C55E",
            "subtitle": "Protection success rate",
            "details": "Shows how often your safety system prevented a threat situation.",
        },
        "response_time": {
            "id": "response_time",
            "title": "Response Time",
            "value": "2.4s",
            "trend": -5,
            "color": "#3B82F6",
            "subtitle": "Avg system reaction time",
            "details": "How quickly your system reacts to risk triggers.",
        },
        "false_alarms": {
            "id": "false_alarms",
            "title": "False Alarms",
            "value": "3%",
            "trend": -8,
            "color": "#F59E0B",
            "subtitle": "Unnecessary triggers",
            "details": "Percentage of alerts triggered without real danger.",
        },
        "safe_coverage": {
            "id": "safe_coverage",
            "title": "Safe Coverage",
            "value": "86%",
            "trend": 15,
            "color": "#A855F7",
            "subtitle": "Area safety availability",
            "details": "How strong your area is in terms of mapped safety points.",
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
