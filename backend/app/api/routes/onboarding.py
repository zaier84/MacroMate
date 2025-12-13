from typing import Any
from fastapi import APIRouter, Body, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_onboarding_service, get_user_service
from app.auth.deps import Principal, get_current_user
from app.services.onboarding_service import OnboardingService
from app.services.user_service import UserService

router = APIRouter(prefix="/onboarding", tags=["onboarding"])

allowed_steps = {
    "personal_info",
    "body_metrics",
    "goals",
    "unit_preferences",
    "dietary_preferences",
    "meal_preferences",
    "macro_distribution",
    "lifestyle",
    "notifications",
    "health_integrations",
}

class GenericPayload(BaseModel):
    data: dict[str, Any] = {}

@router.get("/", status_code=status.HTTP_200_OK)
async def get_progress(
    user: Principal = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service)
):
    return svc.get_progress(user.uid)

@router.patch("/step/{step_name}", status_code=status.HTTP_200_OK)
def save_step(
    step_name: str,
    payload: dict[str, Any] = Body(...),
    user: Principal = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
    user_service: UserService = Depends(get_user_service),
):
    """
    Save partial payload for a given step.
    Client should send JSON body for that step (schema validated in frontend or validated server-side if desired).
    Example: PATCH /onboarding/step/personal_info
             { "full_name": "Alice", "date_of_birth": "1997-04-12" }
    """
    # Optionally, you can validate step_name against allowed list here

    if step_name not in allowed_steps:
        raise HTTPException(status_code=400, detail="Unknown onboarding step")

    result = svc.save_step(user.uid, step_name, payload)

    if user.email:
        user_service.ensure_user_exists(user.uid, user.email, user.name)
    else:
        # if personal_info just saved with email, use it
        if step_name == "personal_info" and payload.get("email"):
            user_service.ensure_user_exists(user.uid, payload.get("email"), payload.get("full_name") or payload.get("name"))

    return {"ok": True, "step": step_name}

@router.post("/complete", status_code=status.HTTP_200_OK)
def complete_onboarding(
    user: Principal = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service)
):
    try:
        return svc.complete_onboarding(user.uid)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to complete onboarding")

@router.post("/submit", status_code=status.HTTP_200_OK)
def submit_onboarding(
    payload: dict[str, Any] = Body(...),
    user: Principal = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
    user_service: UserService = Depends(get_user_service),
):
    """
    Accept full onboarding payload from client (single request).
    The payload can use camelCase keys (client-side). This endpoint will normalize and split
    the payload into the known onboarding steps, save them and then complete onboarding.
    """
    try:
        normalized = _normalize_onboarding_payload(payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Save each recognized step (use existing save_step, which also publishes events)
    for step_name, step_payload in normalized.items():
        svc.save_step(user.uid, step_name, step_payload)

        # For personal_info step, ensure user record exists / updated
        if step_name == "personal_info":
            # ensure_user_exists will create minimal user record if not present
            user_service.ensure_user_exists(user.uid, step_payload.get("email"), step_payload.get("full_name"))

    # Now attempt to complete onboarding (this will validate required steps and write computed calories)
    try:
        result = svc.complete_onboarding(user.uid)
    except ValueError as e:
        # If required fields missing, bubble up 400 with message
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to complete onboarding")

    return result

@router.get("/summary", status_code=status.HTTP_200_OK)
def onboarding_summary(
    svc: OnboardingService = Depends(get_onboarding_service),
    user: Principal = Depends(get_current_user),
):
    try:
        res = svc.get_onboarding_summary(user.uid)
        return res
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        # log if you have a logger; return 500
        raise HTTPException(status_code=500, detail="Failed to build onboarding summary")


def _normalize_onboarding_payload(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """
    Convert the incoming client payload (possibly camelCase) into the canonical steps:
      personal_info, body_metrics, goals, unit_preferences, dietary_preferences,
      meal_preferences, macro_distribution, lifestyle, notifications

    Returns dict: { step_name: step_payload_dict, ... }
    """

    out: dict[str, dict[str, Any]] = {}

    # helper to fetch camelCase or snake_case
    def g(d, *keys, default=None):
        for k in keys:
            if k in d:
                return d[k]
            # try camelCase -> snake_case
            alt = ''.join([keys[i].capitalize() if i>0 else keys[i] for i in k.split('_')])  # not full but ok
            if alt in d:
                return d[alt]
        return default

    # --- PERSONAL INFO ---
    personal = {}
    full_name = payload.get("fullName") or payload.get("full_name") or payload.get("name")
    if full_name:
        personal["full_name"] = full_name
    email = payload.get("email") or payload.get("Email")
    if email:
        personal["email"] = email
    dob = payload.get("dateOfBirth") or payload.get("date_of_birth")
    if dob:
        personal["date_of_birth"] = dob
    gender = payload.get("gender")
    if gender:
        personal["gender"] = gender
    weight_unit = payload.get("weightUnit") or payload.get("weight_unit")
    if weight_unit:
        personal["weight_unit"] = weight_unit
    height_unit = payload.get("heightUnit") or payload.get("height_unit")
    if height_unit:
        personal["height_unit"] = height_unit
    if personal:
        out["personal_info"] = personal

    # --- BODY METRICS ---
    body = {}
    # try structured ft/in or cm
    if "height_cm" in payload:
        body["height_cm"] = payload["height_cm"]
    else:
        # support compound "height" like "5'7\"" or payload fields height_ft, height_in
        height = payload.get("height") or payload.get("height_str")
        if height and isinstance(height, str):
            # parse patterns like 5'7" or 5 ft 7 in
            import re
            m = re.match(r"^\s*(\d+)[\'\s]+(\d+)", height)
            if m:
                body["height_ft"] = int(m.group(1))
                body["height_in"] = int(m.group(2))
        if "height_ft" in payload or "heightIn" in payload or "height_in" in payload:
            if "height_ft" in payload:
                body["height_ft"] = payload["height_ft"]
            elif "heightIn" in payload:
                body["height_ft"] = payload["heightIn"]
            if "height_in" in payload:
                body["height_in"] = payload["height_in"]
            elif "heightInches" in payload:
                body["height_in"] = payload["heightInches"]

    # weight: try kg first, then lbs, then generic
    if "weight_kg" in payload:
        body["weight_kg"] = payload["weight_kg"]
    elif "weight" in payload:
        # check units request or personal weightUnit
        wunit = weight_unit or personal.get("weight_unit") or payload.get("weightUnit")
        if wunit and str(wunit).lower().startswith("lb"):
            body["weight_lbs"] = payload["weight"]
        else:
            try:
                body["weight_kg"] = float(payload["weight"])
            except Exception:
                body["weight"] = payload["weight"]
    if "age" in payload:
        body["age"] = payload["age"]
    if body:
        out["body_metrics"] = body

    # --- GOALS ---
    goals = {}
    if "primaryGoal" in payload or "goal_type" in payload or "primary_goal" in payload:
        goals["goal_type"] = payload.get("primaryGoal") or payload.get("goal_type") or payload.get("primary_goal")
    # target weight
    if "targetWeight" in payload:
        goals["target_weight_kg"] = payload["targetWeight"]
    elif "target_weight_kg" in payload:
        goals["target_weight_kg"] = payload["target_weight_kg"]
    # rate/preset
    if "weightChangeRate" in payload:
        # map UI strings to server presets if possible
        rc = payload["weightChangeRate"]
        rc_map = {"slow": "conservative", "standard": "standard", "aggressive": "aggressive", "conservative": "conservative"}
        if str(rc).lower() in rc_map:
            goals["rate_choice"] = rc_map[str(rc).lower()]
        elif str(rc).lower() == "custom":
            # expect custom_rate field
            if "customRate" in payload:
                goals["custom_rate_kg_per_week"] = payload["customRate"]
    # if client computed weekly_goal directly:
    if "weekly_goal" in payload:
        goals["weekly_goal"] = payload["weekly_goal"]
    if goals:
        out["goals"] = goals

    # --- ACTIVITY / LIFESTYLE ---
    lifestyle = {}
    if "activityLevel" in payload:
        lifestyle["activity_level"] = payload["activityLevel"]
    elif "activity_level" in payload:
        lifestyle["activity_level"] = payload["activity_level"]
    if "activityMultiplier" in payload:
        lifestyle["activity_multiplier"] = payload["activityMultiplier"]
    if lifestyle:
        out["lifestyle"] = lifestyle

    # --- DIETARY PREFERENCES ---
    dietary = {}
    if "dietType" in payload:
        dietary["diet_type"] = payload["dietType"]
    if "allergies" in payload:
        dietary["allergies"] = payload["allergies"]
    if "dislikes" in payload:
        dietary["exclude_foods"] = payload["dislikes"]
    if dietary:
        out["dietary_preferences"] = dietary

    # --- MACRO DISTRIBUTION ---
    macro = {}
    # accept either percent or grams, but prefer percent
    if "proteinPercent" in payload or "protein_pct" in payload:
        macro["protein_pct"] = payload.get("proteinPercent") or payload.get("protein_pct")
    if "carbsPercent" in payload or "carbs_pct" in payload:
        macro["carbs_pct"] = payload.get("carbsPercent") or payload.get("carbs_pct")
    if "fatPercent" in payload or "fat_pct" in payload:
        macro["fat_pct"] = payload.get("fatPercent") or payload.get("fat_pct")
    if macro:
        out["macro_distribution"] = macro

    # --- MEAL PREFERENCES ---
    mp = {}
    if "mealCount" in payload:
        mp["meals_per_day"] = payload["mealCount"]
    if "mealTimes" in payload:
        mp["preferred_meal_times"] = payload["mealTimes"]
    if "favoriteCuisines" in payload:
        mp["favorite_cuisines"] = payload["favoriteCuisines"]
    if mp:
        out["meal_preferences"] = mp

    # --- NOTIFICATIONS ---
    if "notifications" in payload:
        out["notifications"] = payload["notifications"]

    # --- UNIT PREFERENCES —
    if "units" in payload:
        out["unit_preferences"] = {"units": payload["units"]}
    else:
        # fallback using personal info units
        if personal.get("weight_unit") or personal.get("height_unit"):
            out["unit_preferences"] = {"units": {"weight": personal.get("weight_unit"), "height": personal.get("height_unit")}}

    return out
