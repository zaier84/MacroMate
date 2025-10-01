import datetime as dt
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from pydantic import BaseModel, Field, field_validator
from app.api.deps import get_food_log_service, get_nutrition_service, get_user_service
from app.auth.deps import Principal, get_current_user
from app.services.food_log_service import FoodLogService, NotFoundError
from app.services.nutrition_service import NutritionService
from app.services.user_service import UserService

router = APIRouter(prefix="/nutrition", tags=["nutrition"])

# -----------------------
# Validation / Schemas
# -----------------------
ALLOWED_MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}

ALLOWED_UNITS = {"g", "ml", "piece", "slice", "cup", "oz"}

class FoodItemIn(BaseModel):
    food_api_id: str | None = None
    name: str
    brand: str | None = None
    quantity: float | None = None
    unit: str | None = None
    calories: int | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fats_g: float | None = None
    raw: Any | None = None

    @field_validator("quantity", "calories", "protein_g", "carbs_g", "fats_g", mode="before")
    def non_negative(cls, v):
        if v is None:
            return None
        try:
            num = float(v)
        except Exception:
            raise ValueError("must be a number")
        if num < 0:
            raise ValueError("must be >= 0")
        # calories should be int
        return int(num) if isinstance(v, int) or (isinstance(v, float) and v.is_integer()) and cls.__name__ == "FoodItemIn" and False else num

    @field_validator("unit")
    def check_unit(cls, v):
        if v is None:
            return None
        if v not in ALLOWED_UNITS:
            raise ValueError(f"unit must be one of {sorted(ALLOWED_UNITS)}")
        return v

class LogRequest(BaseModel):
    date: dt.date | None = None
    meal_type: str = Field(..., description="breakfast|lunch|dinner|snack")
    consumed_at: dt.datetime | None = None
    foods: list[FoodItemIn]

    @field_validator("meal_type")
    def validate_meal_type(cls, v):
        if v not in ALLOWED_MEAL_TYPES:
            raise ValueError(f"meal_type must be one of {sorted(ALLOWED_MEAL_TYPES)}")
        return v

class UpdateEntryPayload(BaseModel):
    quantity: float | None = None
    unit: str | None = None
    calories: int | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fats_g: float | None = None
    food_name: str | None = None
    brand: str | None = None
    consumed_at: dt.datetime | None = None
    meal_type: str | None = None
    date: dt.datetime | None = None

    @field_validator("unit")
    def check_unit(cls, v):
        if v is None:
            return v
        if v not in ALLOWED_UNITS:
            raise ValueError(f"unit must be one of {sorted(ALLOWED_UNITS)}")
        return v

    @field_validator("meal_type")
    def check_meal_type(cls, v):
        if v is None:
            return v
        if v not in ALLOWED_MEAL_TYPES:
            raise ValueError(f"meal_type must be one of {sorted(ALLOWED_MEAL_TYPES)}")
        return v

# -----------------------
# Endpoints
# -----------------------
@router.get("/daily")
def get_daily_nutrition(
    user: Principal = Depends(get_current_user),
    svc: NutritionService = Depends(get_nutrition_service)
):
    try:
        return svc.get_daily_nutrition(user.uid)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/log", status_code=201)
def log_foods(
    payload: LogRequest,
    user: Principal = Depends(get_current_user),
    svc: FoodLogService = Depends(get_food_log_service),
):
    day = payload.date or dt.datetime.utcnow().date()
    created = svc.add_food_entries(user.uid, day, payload.meal_type, [f.dict() for f in payload.foods], payload.consumed_at)
    return {"ok": True, "created": created}

@router.get("/logs")
def list_logs(
    day: dt.date = Query(None, description="YYYY-MM-DD; defaults to today if omitted"),
    limit: int = Query(100, ge=0, le=500),
    offset: int = Query(0, ge=0),
    user: Principal = Depends(get_current_user),
    svc: FoodLogService = Depends(get_food_log_service),
):
    day_val = day or dt.datetime.utcnow().date()
    rows = svc.get_entries_by_day(user.uid, day_val, limit=limit, offset=offset)
    return {"date": day_val.isoformat(), "count": len(rows), "items": rows}

@router.get("/log/{entry_id}")
def get_log_entry(
    entry_id: str = Path(..., min_length=1),
    user: Principal = Depends(get_current_user),
    svc: FoodLogService = Depends(get_food_log_service),
):
    entry = svc.get_entry(entry_id, user.uid)
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    return entry

@router.patch("/log/{entry_id}")
def update_log_entry(
    entry_id: str,
    payload: UpdateEntryPayload,
    user: Principal = Depends(get_current_user),
    svc: FoodLogService = Depends(get_food_log_service),
):
    try:
        updated = svc.update_entry(entry_id, user.uid, payload.model_dump(exclude_unset=True))
        return {"ok": True, "updated": updated}
    except NotFoundError:
        raise HTTPException(status_code=404, detail="Entry not found")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to update entry")

@router.delete("/log/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_log_entry(
    entry_id: str,
    user: Principal = Depends(get_current_user),
    svc: FoodLogService = Depends(get_food_log_service),
):
    try:
        svc.delete_entry(entry_id, user.uid)
        return {} # 204 will have no body
    except NotFoundError:
        raise HTTPException(status_code=404, detail="Entry not found")
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to delete entry")


@router.get("/summary")
def get_daily_summary(
    day: dt.date | None = Query(..., description="Date in YYYY-MM-DD"),
    user: Principal = Depends(get_current_user),
    user_svc: UserService = Depends(get_user_service),
    food_log_svc: FoodLogService = Depends(get_food_log_service),
):
    try:
        day_val = day or dt.datetime.utcnow().date()
        user_data = user_svc.get_user(user.uid)
        if not user_data:
            raise HTTPException(status_code=404, detail="User not found")

        summary = food_log_svc.get_summary(user.uid, day_val, user_data.onboarding_summary)
        return summary
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/weekly")
def weekly_summary(
    user: Principal = Depends(get_current_user),
    user_svc: UserService = Depends(get_user_service),
    food_log_svc: FoodLogService = Depends(get_food_log_service),
):
    user_data = user_svc.get_user(user.uid)
    if not user_data:
        raise HTTPException(status_code=404, detail="User not found")

    today = dt.date.today()

    start_of_this_week = today - dt.timedelta(days=today.weekday())
    start = start_of_this_week - dt.timedelta(days=7)
    end = start + dt.timedelta(days=6)

    return food_log_svc.get_range_summary(user.uid, start, end, user_data.onboarding_summary)

@router.get("/monthly")
def monthly_summary(
    user: Principal = Depends(get_current_user),
    user_svc: UserService = Depends(get_user_service),
    food_log_svc: FoodLogService = Depends(get_food_log_service),
):
    user_data = user_svc.get_user(user.uid)
    if not user_data:
        raise HTTPException(status_code=404, detail="User not found")

    today = dt.date.today()

    first_day_this_month = today.replace(day=1)
    last_day_prev_month = first_day_this_month - dt.timedelta(days=1)
    start = last_day_prev_month.replace(day=1)
    end = last_day_prev_month

    return food_log_svc.get_range_summary(user.uid, start, end, user_data.onboarding_summary)

@router.get("/dashboard")
def get_dashboard(
    day: dt.date | None = Query(..., description="Date in YYYY-MM-DD"),
    user: Principal = Depends(get_current_user),
    user_svc: UserService = Depends(get_user_service),
    nutrition_service: NutritionService = Depends(get_nutrition_service),
    food_log_svc: FoodLogService = Depends(get_food_log_service),
):
    day = day or dt.datetime.utcnow().date()

    user_obj = user_svc.get_user(user.uid)
    if not user_obj:
        raise HTTPException(status_code=404, detail="User not found")

    if not user_obj.is_profile_complete:
        raise HTTPException(status_code=400, detail="Onboarding incomplete")

    # targets
    try:
        target_calories, target_macros = nutrition_service.get_daily_nutrition(user.uid)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # actual intake
    summary = food_log_svc.get_summary(user.uid, day, user_obj.onboarding_summary)

    totals = summary.get("totals", {})
    consumed_cal = totals.get("calories", 0)
    consumed_pro = totals.get("protein_g", 0.0)
    consumed_carbs = totals.get("carbs_g", 0.0)
    consumed_fats = totals.get("fats_g", 0.0)

    # compute remaining
    remaining_cal = target_calories - consumed_cal if target_calories is not None else None
    remaining_pro = remaining_carbs = remaining_fats = None
    if target_macros:
        remaining_pro = max(0, int(target_macros.get("protein_g", 0) - consumed_pro))
        remaining_carbs = max(0, int(target_macros.get("carbs_g", 0) - consumed_carbs))
        remaining_fats = max(0, int(target_macros.get("fats_g", 0) - consumed_fats))

    # progress %
    cal_pct = round(consumed_cal * 100.0 / target_calories, 1) if target_calories else None
    protein_pct = round(consumed_pro * 100.0 / target_macros["protein_g"], 1) if target_macros and target_macros.get("protein_g") else None
    carbs_pct = round(consumed_carbs * 100.0 / target_macros["carbs_g"], 1) if target_macros and target_macros.get("carbs_g") else None
    fats_pct = round(consumed_fats * 100.0 / target_macros["fats_g"], 1) if target_macros and target_macros.get("fats_g") else None

    return {
        "date": day.isoformat(),
        "targets": {"calories": target_calories, "macro_targets": target_macros},
        "consumed": totals,
        "remaining": {
            "calories": remaining_cal,
            "protein_g": remaining_pro,
            "carbs_g": remaining_carbs,
            "fats_g": remaining_fats,
        },
        "progress_pct": {
            "calories_pct": cal_pct,
            "protein_pct": protein_pct,
            "carbs_pct": carbs_pct,
            "fats_pct": fats_pct,
        },
        "meals": summary.get("meals", {})
    }
