# App/backend/routes/police_stations.py
from math import radians, sin, cos, sqrt, atan2

from fastapi import APIRouter, Query

from database.collections import get_collections

router = APIRouter(prefix="/police-stations", tags=["police-stations"])


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius_km = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return radius_km * c


@router.get("")
async def list_police_stations():
    collections = get_collections()
    stations_col = collections["police_stations"]

    docs = await stations_col.find({}, {"_id": 0}).to_list(length=500)
    return {"stations": docs}


@router.get("/nearest")
async def nearest_police_station(
    lat: float = Query(...),
    lng: float = Query(...),
):
    collections = get_collections()
    stations_col = collections["police_stations"]

    docs = await stations_col.find({}, {"_id": 0}).to_list(length=500)
    if not docs:
        return {"station": None}

    nearest = None
    nearest_distance = None

    for station in docs:
        station_lat = float(station.get("lat", 0.0))
        station_lng = float(station.get("lng", 0.0))

        distance = _haversine_km(lat, lng, station_lat, station_lng)
        if nearest_distance is None or distance < nearest_distance:
            nearest_distance = distance
            nearest = station

    if nearest is None:
        return {"station": None}

    nearest["distance_km"] = round(nearest_distance or 0.0, 2)
    return {"station": nearest}
