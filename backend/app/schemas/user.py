from typing import Any, Dict, List
from pydantic import BaseModel, EmailStr
from datetime import date, datetime

class UserCreate(BaseModel):
    email: EmailStr
    name: str | None = None
    dob: date | None = None
    gender: str | None = None
    height_cm: int | None = None
    preferences: Dict[str, Any] | None = None
    goal: str | None = None
    allergies: List[str] | None = None

class UserUpdate(BaseModel):
    """Schema for updating user profile."""
    name: str | None = None
    dob: date | None = None
    sex: str | None = None
    height_cm: int | None = None
    preferences: Dict[str, Any] | None = None
    goal: str | None = None
    allergies: List[str] | None = None

class UserResponse(BaseModel):
    user_id: str
    email: EmailStr
    name: str | None = None
    dob: date | None = None
    sex: str | None = None
    height_cm: int | None = None
    preferences: Dict[str, Any]| None = None
    goal: str | None = None
    allergies: List[str] | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class PreferencesUpdate(BaseModel):
    units: dict[str, str] | None = None
    diet_type: str | None = None
    allergies: list[str] | None = None
    excluded_foods: list[str] | None = None
    meals_per_day: int | None = None
    preferred_meal_times: list[str] | None = None

    class Config:
        extra = "forbid"
