from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import List
from datetime import date
from app.auth.deps import Principal, get_current_user
from app.api.deps import get_meal_service
from app.services.meal_service import MealService

router = APIRouter(prefix="/mealplans", tags=["mealplans"])

class GenerateRequest(BaseModel):
    start_date: date = Field(...)
    days: int = Field(3, ge=1, le=30)
    meals: List[str] | None = None
    tolerance_pct: int = Field(10, ge=0, le=100)

class SavePlanRequest(BaseModel):
    plan: dict

class AcceptMealRequest(BaseModel):
    items: List[dict] | None = None

@router.post("/generate", status_code=status.HTTP_200_OK)
def generate_plan(payload: GenerateRequest, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    try:
        plan = svc.generate_plan(user.uid, payload.start_date, days=payload.days, meals=payload.meals, tolerance_pct=payload.tolerance_pct)
        return plan
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/", status_code=status.HTTP_201_CREATED)
def save_plan(payload: SavePlanRequest, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    try:
        plan = svc.save_plan(user.uid, payload.plan)
        return plan
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", status_code=status.HTTP_200_OK)
def list_plans(start: date | None = Query(None), end: date | None = Query(None), user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    return svc.get_plans(user.uid, start=start, end=end)

@router.get("/{plan_id}", status_code=status.HTTP_200_OK)
def get_plan(plan_id: str, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    p = svc.get_plan(plan_id, user.uid)
    if not p:
        raise HTTPException(status_code=404, detail="Not found")
    return p

@router.post("/{plan_id}/accept", status_code=status.HTTP_201_CREATED)
def accept_meal(plan_id: str, iso_date: str = Query(..., description="YYYY-MM-DD"), meal_type: str = Query(...), payload: AcceptMealRequest | None = None, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    try:
        res = svc.accept_meal(user.uid, plan_id, iso_date, meal_type, items=payload.items if payload else None)
        return res
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{plan_id}/shopping-list", status_code=status.HTTP_200_OK)
def shopping_list(plan_id: str, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    try:
        return svc.shopping_list(user.uid, plan_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
