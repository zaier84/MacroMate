from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional, Dict, Any
from datetime import datetime, date

# Helper for MongoDB ObjectId (if you want to use it in Pydantic)
# from bson import ObjectId
# class PyObjectId(ObjectId):
#     @classmethod
#     def __get_validators__(cls):
#         yield cls.validate
#     @classmethod
#     def validate(cls, v):
#         if not ObjectId.is_valid(v):
#             raise ValueError("Invalid ObjectId")
#         return ObjectId(v)
#     @classmethod
#     def __modify_schema__(cls, field_schema: Dict[str, Any]):
#         field_schema.update(type="string")


class OnboardingProjection(BaseModel):
    is_complete: bool = False
    current_step: Optional[str] = None
    last_saved: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    progress: Optional[Dict[str, Any]] = None
    summary: Optional[Dict[str, Any]] = None

class UserProjection(BaseModel):
    id: str = Field(alias="_id")
    email: EmailStr
    name: Optional[str] = None
    goal: Optional[str] = None
    diet_type: Optional[str] = None
    allergies: Optional[List[str]] = None
    status: str = "active"
    last_synced: datetime = Field(default_factory=datetime.utcnow)
    onboarding: Optional[OnboardingProjection] = None
    current_plan_summary: Optional[Dict[str, Any]] = None

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat()}

class FoodItemLog(BaseModel):
    """Pydantic model for a single food item within a meal log."""
    food_id: Optional[str] = None # Reference to MySQL.foods.food_id
    name: str
    serving_g: Optional[float] = None # Use float for grams
    serving_ml: Optional[float] = None # Use float for milliliters
    calories: Optional[int] = None
    protein_g: Optional[float] = None
    carbs_g: Optional[float] = None
    fat_g: Optional[float] = None
    source: str = "manual" # "manual", "ai_recognition", "recipe"

class MealLogEntry(BaseModel):
    """Pydantic model for a single meal within a daily meal log."""
    meal_id: str # ULID/UUID for this specific meal entry
    meal_type: str # e.g., "breakfast", "lunch", "dinner", "snack"
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    items: List[FoodItemLog]
    notes: Optional[str] = None

class MealLog(BaseModel):
    """Pydantic model for the meal_logs collection in MongoDB (daily log)."""
    id: str = Field(alias="_id") # Using user_id as _id for daily log, or ObjectId
    user_id: str
    date: date # Date of the meal log (start of day)
    meals: List[MealLogEntry] = []
    daily_totals: Optional[Dict[str, Any]] = None # e.g., {"calories": 1800, "protein_g": 95}
    extras: Optional[Dict[str, Any]] = None # e.g., {"hydration_ml": 2200, "mood": "energetic"}
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat(), date: lambda d: d.isoformat()}

class ExerciseSet(BaseModel):
    """Pydantic model for a single set within an exercise."""
    set_num: int
    reps: Optional[int] = None
    weight_kg: Optional[float] = None
    duration_min: Optional[float] = None # For cardio sets
    distance_km: Optional[float] = None # For cardio sets

class ExercisePerformed(BaseModel):
    """Pydantic model for an exercise performed within a workout log."""
    exercise_id: Optional[str] = None # Reference to MySQL.exercises.exercise_id
    name: str
    sets: List[ExerciseSet]
    notes: Optional[str] = None

class WorkoutLog(BaseModel):
    """Pydantic model for the workout_logs collection in MongoDB."""
    id: str = Field(alias="_id") # ObjectId
    user_id: str
    date: date
    workout_id: str # ULID/UUID for this specific workout session
    workout_name: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    duration_minutes: Optional[float] = None
    exercises_performed: List[ExercisePerformed] = []
    total_calories_burned: Optional[int] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat(), date: lambda d: d.isoformat()}

class WeightLog(BaseModel):
    """Pydantic model for the weight_logs collection in MongoDB."""
    id: str = Field(alias="_id") # ObjectId
    user_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    weight_kg: float
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat()}

class Recommendation(BaseModel):
    """Pydantic model for the recommendations collection in MongoDB."""
    id: str = Field(alias="_id") # ObjectId
    user_id: str
    as_of: datetime = Field(default_factory=datetime.utcnow)
    type: str # "daily_targets", "meal_plan_suggestion", "workout_plan_suggestion"
    targets: Optional[Dict[str, Any]] = None # e.g., {"kcal": 2050, "protein_g": 130}
    diet_plan_suggestion: Optional[Dict[str, Any]] = None
    workout_plan_suggestion: Optional[Dict[str, Any]] = None
    explanations: Optional[List[str]] = None
    model_version: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat()}

class Dashboard(BaseModel):
    """Pydantic model for the dashboards collection in MongoDB."""
    id: str = Field(alias="_id") # user_id
    display_name: str
    current_date: date
    daily_macro_summary: Optional[Dict[str, Any]] = None
    daily_target: Optional[Dict[str, Any]] = None
    last_weight_kg: Optional[float] = None
    active_plan_summary: Optional[Dict[str, Any]] = None
    last_workout_summary: Optional[Dict[str, Any]] = None
    last_updated: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda dt: dt.isoformat(), date: lambda d: d.isoformat()}


