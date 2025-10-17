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
