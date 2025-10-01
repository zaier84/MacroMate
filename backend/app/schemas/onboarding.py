from typing import Any
from pydantic import BaseModel, Field, EmailStr
from datetime import date, datetime

class PersonalInfo(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    weight_unit: str | None = None  # 'kg' or 'lbs'
    height_unit: str | None = None  # 'cm' or 'ft-in'

class BodyMetrics(BaseModel):
    weight: float | None = None
    height_cm: int | None = None
    height_ft: int | None = None
    height_in: int | None = None

class SelectGoal(BaseModel):
    primary_goal: str | None = None  # e.g. 'weight_loss', 'muscle_gain', 'maintenance'

class DietaryPreferences(BaseModel):
    diet_type: str | None = None  # 'vegetarian', 'vegan', 'omnivore', etc.
    allergies: list[str] | None = None
    dislikes: list[str] | None = None

class MacroDistribution(BaseModel):
    protein_pct: float | None = None
    carbs_pct: float | None = None
    fat_pct: float | None = None

class GenericStepPayload(BaseModel):
    data: dict[str, Any] = Field(default_factory=dict)

class OnboardingProgressResponse(BaseModel):
    current_step: str
    progress: dict[str, Any]
    is_complete: bool

class OnboardingCompleteResponse(BaseModel):
    ok: bool
    user_id: str
    is_profile_complete: bool
    completed_at: datetime | None = None
