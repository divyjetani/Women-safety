from fastapi import APIRouter
from database.collections import get_collections

router = APIRouter(prefix="/help", tags=["help"])


@router.get("/faqs")
async def get_faqs():
    collections = get_collections()
    faqs_col = collections["faqs"]
    
    docs = await faqs_col.find().to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    
    return docs
