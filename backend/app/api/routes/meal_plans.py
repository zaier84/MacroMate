from fastapi import APIRouter, Depends, HTTPException, Query, status
from datetime import date

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, Principal
from app.services.meal_plan_service import MealPlanService
from app.core.database import get_db

router = APIRouter(prefix="/meal-plans", tags=["meal-plans"])

class MealPlanGenerateIn(BaseModel):
    days: int = Field(..., ge=1, le=14)

@router.get("")
def get_all_meal_plans(
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    svc = MealPlanService(db)
    return svc.get_all_meal_plans(user.uid)

@router.get("/{plan_id}")
def get_meal_plan(
    plan_id: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    svc = MealPlanService(db)
    return svc.get_meal_plan_by_id(user.uid, plan_id)


@router.post("/generate", status_code=201)
def generate_meal_plan(
    payload: MealPlanGenerateIn,
    user: Principal = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    svc = MealPlanService(db)
    return svc.generate_for_user(
        user_id=user.uid,
        days=payload.days
    )


# @router.post("/generate", status_code=status.HTTP_201_CREATED)
# def generate_meal_plan(
#     start_date: date = Query(...),
#     days: int = Query(7, ge=1, le=14),
#     user: Principal = Depends(get_current_user),
#     db=Depends(get_db),
# ):
#     try:
#         svc = MealPlanService(db)
#         plan = svc.generate_meal_plan(user.uid, start_date, days)
#
#         return {
#             "plan_id": plan.plan_id,
#             "start_date": plan.start_date,
#             "end_date": plan.end_date,
#             "days": plan.days,
#         }
#     except ValueError as e:
#         raise HTTPException(status_code=400, detail=str(e))
#
