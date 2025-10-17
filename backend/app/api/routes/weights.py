from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
import datetime as dt

from app.api.deps import get_weight_service
from app.auth.deps import Principal, get_current_user
from app.services.weight_service import WeightService

router = APIRouter(prefix="/weights", tags=["weights"])

class WeightIn(BaseModel):
    date: dt.date = Field(..., json_schema_extra={"example": "2025-09-22"})
    weight_kg: float = Field(..., json_schema_extra={"example": 72.0})
    note: str | None = None

@router.post("/", status_code=status.HTTP_201_CREATED)
def add_weight(payload: WeightIn, user: Principal = Depends(get_current_user), svc: WeightService = Depends(get_weight_service)):
    res = svc.add_entry(user.uid, payload.date, payload.weight_kg, payload.note)
    return res

@router.get("/", response_model=list[dict], status_code=status.HTTP_200_OK)
def list_weights(start: dt.date | None = Query(None), end: dt.date | None = Query(None), user: Principal = Depends(get_current_user), svc: WeightService = Depends(get_weight_service)):
    return svc.list_entries(user.uid, start=start, end=end)

@router.get("/{entry_id}", status_code=status.HTTP_200_OK)
def get_weight(entry_id: str, user: Principal = Depends(get_current_user), svc: WeightService = Depends(get_weight_service)):
    r = svc.get_entry(entry_id, user.uid)
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    return r

@router.delete("/{entry_id}", status_code=status.HTTP_200_OK)
def delete_weight(entry_id: str, user: Principal = Depends(get_current_user), svc: WeightService = Depends(get_weight_service)):
    ok = svc.delete_entry(entry_id, user.uid)
    if not ok:
        raise HTTPException(status_code=404, detail="Not found")
    return {"ok": True}
