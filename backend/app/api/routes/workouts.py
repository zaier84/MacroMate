from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, PositiveInt
import datetime as dt

from app.api.deps import get_workout_service
from app.auth.deps import Principal, get_current_user
from app.services.workout_service import WorkoutService

router = APIRouter(prefix="/workouts", tags=["workouts"])

class SetIn(BaseModel):
    weight_kg: float = Field(..., ge=0, description="Weight used in kg, must be ≥ 0")
    reps: PositiveInt
    tempo: str | None = None
    rest_s: float | None = Field(None, ge=0, description="Rest time in seconds, must be ≥ 0 if given")
    notes: str | None = None

class ExerciseIn(BaseModel):
    exercise_name: str = Field(..., json_schema_extra={"example": "Squat"})
    sets: Annotated[list[SetIn], Field(min_length=1, description="At least one set is required")]
    notes: str | None = None

class SessionIn(BaseModel):
    date: dt.date = Field(..., json_schema_extra={"example": "2025-09-28"})
    name: str | None = None
    notes: str | None = None

# --- session endpoints ---
@router.post("/sessions", status_code=status.HTTP_201_CREATED)
def create_session(payload: SessionIn, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    return svc.create_session(user.uid, payload.date, payload.name, payload.notes)

@router.get("/sessions", status_code=200)
def list_sessions(start: dt.date | None = Query(None), end: dt.date | None = Query(None), user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    return svc.list_sessions(user.uid, start=start, end=end)

@router.get("/sessions/{session_id}", status_code=200)
def get_session(session_id: str, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    r = svc.get_session(session_id, user.uid)
    if not r:
        raise HTTPException(status_code=404, detail="Session not found")
    return r

@router.patch("/sessions/{session_id}", status_code=200)
def update_session(session_id: str, payload: dict, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    r = svc.update_session(session_id, user.uid, payload)
    if not r:
        raise HTTPException(status_code=404, detail="Session not found")
    return r

@router.delete("/sessions/{session_id}", status_code=200)
def delete_session(session_id: str, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    ok = svc.delete_session(session_id, user.uid)
    if not ok:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"ok": True}

# --- exercise endpoints ---
@router.post("/sessions/{session_id}/exercises", status_code=201)
def add_exercise(session_id: str, payload: ExerciseIn, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    try:
        return svc.add_exercise(session_id, user.uid, payload.dict())
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/sessions/{session_id}/exercises", status_code=200)
def list_exercises(session_id: str, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    return svc.list_exercises_for_session(session_id, user.uid)

@router.patch("/exercises/{entry_id}", status_code=200)
def update_exercise(entry_id: str, payload: dict, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    r = svc.update_exercise(entry_id, user.uid, payload)
    if r is None:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return r

@router.delete("/exercises/{entry_id}", status_code=200)
def delete_exercise(entry_id: str, user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    ok = svc.delete_exercise(entry_id, user.uid)
    if not ok:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return {"ok": True}

# --- stats endpoint ---
@router.get("/exercises/stats", status_code=200)
def exercise_stats(exercise_name: str = Query(..., min_length=1), start: dt.date | None = Query(None), end: dt.date | None = Query(None), user: Principal = Depends(get_current_user), svc: WorkoutService = Depends(get_workout_service)):
    # exercise_name may contain spaces; fastapi handles that
    try:
        return svc.get_exercise_stats(user.uid, exercise_name, start=start, end=end)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

