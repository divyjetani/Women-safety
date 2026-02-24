from fastapi import APIRouter, HTTPException
from schemas.sos import SOSRequest, SOSResponse
from database.collections import get_collections

router = APIRouter(prefix="/sos", tags=["sos"])


@router.post("", response_model=SOSResponse)
async def create_sos_report(request: SOSRequest):
    collections = get_collections()
    sos_reports_col = collections["sos_reports"]
    
    doc = request.dict()
    res = await sos_reports_col.insert_one(doc)
    
    return {
        "success": True,
        "message": "SOS alert sent to emergency contacts",
        "report_id": str(res.inserted_id)
    }
