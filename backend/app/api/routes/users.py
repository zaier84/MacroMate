from fastapi import APIRouter, Depends, status, HTTPException
from app.schemas.user import PreferencesUpdate, UserCreate, UserUpdate, UserResponse
from app.services.user_service import UserService
from app.api.deps import get_user_service, get_current_user, Principal

router = APIRouter(prefix="/users", tags=["users"])

# deprecated
# @router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
# async def register_user(
#     user_data: UserCreate,
#     user_service: UserService = Depends(get_user_service),
#     current_user: Principal = Depends(get_current_user)
# ):
#     """
#     Registers a new user in the system after Firebase authentication.
#     The Firebase UID is used as the primary key.
#     """
#     if user_service.get_user(current_user.uid):
#         raise HTTPException(
#             status_code=status.HTTP_409_CONFLICT,
#             detail="User already registered in the database."
#         )
#
#     db_user = user_service.create_user(current_user.uid, user_data)
#     return db_user

@router.get("/{user_id}/profile", response_model=UserResponse)
async def get_user_profile(
    user_id: str,
    user_service: UserService = Depends(get_user_service),
    current_user: Principal = Depends(get_current_user)
):
    """
    Retrieves a user's profile by their user_id (Firebase UID).
    Only allows access to one's own profile or if authorized (not implemented yet).
    """
    if user_id != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to view this profile."
        )

    user = user_service.get_user(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")
    return user

@router.put("/{user_id}/profile", response_model=UserResponse)
async def update_user_profile(
    user_id: str,
    user_data: UserUpdate,
    user_service: UserService = Depends(get_user_service),
    current_user: Principal = Depends(get_current_user)
):
    """
    Updates a user's profile by their user_id (Firebase UID).
    Only allows updating one's own profile.
    """
    if user_id != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to update this profile."
        )

    updated_user = user_service.update_user(user_id, user_data)
    return updated_user


@router.get("/me/status")
async def get_profile_status(
    current_user: Principal = Depends(get_current_user),
    user_service: UserService = Depends(get_user_service)
):
    user = user_service.get_user(current_user.uid)
    if not user:
        if current_user.email:
            created = user_service.ensure_user_exists(current_user.uid, current_user.email, current_user.name)
            if created:
                user = created

    if not user:
        # can't create without email — frontend should ask for email in onboarding personal_info
        return {"isProfileComplete": False}
    return {"isProfileComplete": bool(user.is_profile_complete)}


@router.put("/me/preferences")
async def update_user_preferences(
    update: PreferencesUpdate,
    user_service: UserService = Depends(get_user_service),
    current_user: Principal = Depends(get_current_user),
):
    updated_prefs = user_service.update_preferences(current_user.uid, update.dict(exclude_none=True))
    return {"message": "Preferences updated successfully", "preferences": updated_prefs}


@router.get("/me/daily-targets")
async def get_daily_targets(
    user_service: UserService = Depends(get_user_service),
    current_user: Principal = Depends(get_current_user),
):
    user = user_service.get_user(current_user.uid)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_profile_complete:
        raise HTTPException(status_code=400, detail="Onboarding incomplete")

    summary = user.onboarding_summary or {}
    return {
        "daily_calories": summary.get("daily_calories"),
        "macro_targets": summary.get("macro_targets"),
        "onboarding_summary": summary
    }


# (TEMPORARY FOR TESTING)
from app.events.projection_service import get_projection_service, ProjectionService

@router.post("/process-events", status_code=status.HTTP_200_OK)
async def process_all_pending_events(
    projection_service: ProjectionService = Depends(get_projection_service)
):
    """
    TEMPORARY: Manually triggers the processing of all pending events
    in the in-memory queue to update MongoDB projections.
    """
    projection_service.process_events()
    return {"message": "Events processed."}











