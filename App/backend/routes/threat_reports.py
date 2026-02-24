from fastapi import APIRouter
from database.collections import get_collections

router = APIRouter(prefix="/threat-reports", tags=["threat-reports"])


@router.get("")
async def get_threat_reports():
    collections = get_collections()
    threat_reports_col = collections["threat_reports"]
    
    docs = await threat_reports_col.find().to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    
    return docs
