import datetime as dt
from sqlalchemy import Float, Integer, String, Date, SmallInteger, JSON, Enum, Boolean, TIMESTAMP
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(String(128), primary_key=True, index=True) # Firebase uid
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(120))
    dob: Mapped[dt.date | None] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(Enum('male', 'female', 'other', name="gender_enum"), nullable=True)
    height_cm: Mapped[int | None] = mapped_column(SmallInteger)
    preferences: Mapped[dict | None] = mapped_column(JSON) # Stores JSON object for cuisine, diet_type, etc.
    goal: Mapped[str | None] = mapped_column(String(50))
    allergies: Mapped[list | None] = mapped_column(JSON) # Stores JSON array for allergies
    is_profile_complete: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    onboarding_summary: Mapped[dict | None] = mapped_column(MutableDict.as_mutable(JSON), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<User(user_id='{self.user_id}', email='{self.email}')>"

class UserOnboarding(Base):
    """
    Stores progressive onboarding answers per user. Authoritative source for in-progress onboarding.
    """
    __tablename__ = "user_onboarding"

    user_onboarding_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)  # uuid4 hex
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    current_step: Mapped[str] = mapped_column(String(64), nullable=False, default="personal_info")
    progress: Mapped[dict | None] = mapped_column(MutableDict.as_mutable(JSON), nullable=True)  # e.g. {"personal_info": {...}, "body_metrics": {...}}
    is_complete: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<UserOnboarding(user_onboarding_id='{self.user_onboarding_id}', user_id='{self.user_id}')>"

class FoodEntry(Base):
    __tablename__ = "food_entries"

    entry_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)  # UUID hex
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)     # match users.user_id length
    date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)              # day of entry
    meal_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True)    # breakfast/lunch/dinner/snack
    consumed_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, nullable=False, server_default=func.now())  # timestamp user consumed
    food_api_id: Mapped[str | None] = mapped_column(String(128), nullable=True)     # id from provider (fdcId)
    food_name: Mapped[str] = mapped_column(String(255), nullable=False)               # cached name
    brand: Mapped[str | None] = mapped_column(String(255), nullable=True)
    quantity: Mapped[float | None] = mapped_column(Float, nullable=True)           # numeric amount (e.g. 150)
    unit: Mapped[str | None] = mapped_column(String(32), nullable=True)            # 'g', 'ml', 'piece'
    calories: Mapped[int | None] = mapped_column(Integer, nullable=True)
    protein_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    carbs_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    fats_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    raw: Mapped[dict | None] = mapped_column(JSON, nullable=True)                  # raw provider payload for auditing
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())

class WeightEntry(Base):
    __tablename__ = "weight_entries"

    entry_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)   # day of entry
    weight_kg: Mapped[float] = mapped_column(Float, nullable=False)
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<WeightEntry(entry_id='{self.entry_id}', user_id='{self.user_id}', date='{self.date}', weight_kg={self.weight_kg})>"

# Workout session for grouping exercises (e.g. "Leg Day", date)
class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    session_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(
        TIMESTAMP, server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self):
        return f"<WorkoutSession(session_id='{self.session_id}', user_id='{self.user_id}', date='{self.date}')>"

# Exercise entries stored per session. `sets` is JSON: list of {"weight_kg": float, "reps": int}
class ExerciseEntry(Base):
    __tablename__ = "exercise_entries"

    entry_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    session_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    exercise_name: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    sets: Mapped[list | None] = mapped_column(JSON, nullable=True)  # list of sets
    total_volume: Mapped[float | None] = mapped_column(Float, nullable=True)  # sum(weight * reps)
    notes: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(
        TIMESTAMP, server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self):
        return f"<ExerciseEntry(entry_id='{self.entry_id}', exercise_name='{self.exercise_name}')>"

class Recipe(Base):
    __tablename__ = "recipes"

    recipe_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)  # owner
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    servings: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    # ingredients: list of {food_api_id?, name, quantity, unit, optional nutrition override (calories, protein_g, carbs_g, fats_g), raw}
    ingredients: Mapped[dict | list | None] = mapped_column(JSON, nullable=False)
    # cached nutrition for whole recipe (and per_serving can be derived)
    nutrition: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<Recipe(recipe_id='{self.recipe_id}', title='{self.title}')>"

class MealPlan(Base):
    __tablename__ = "meal_plans"

    plan_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    start_date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    end_date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    # days: mapping from ISO date -> list of meals: [{meal_type, recipe_id?, items: [...], nutrition: {...}}]
    days: Mapped[dict | None] = mapped_column(JSON, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
    updated_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<MealPlan(plan_id='{self.plan_id}', user_id='{self.user_id}', {self.start_date}..{self.end_date})>"

# class MealPlan(Base):
#     __tablename__ = "meal_plans"
#
#     plan_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
#     user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
#
#     start_date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
#     end_date: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
#
#     # ISO date -> meals
#     # "2026-01-02": {
#     #   "breakfast": {...},
#     #   "lunch": {...},
#     #   "dinner": {...}
#     # }
#     days: Mapped[dict] = mapped_column(JSON, nullable=False)
#
#     meta: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # calories, macros, model, version
#
#     created_at: Mapped[dt.datetime] = mapped_column(TIMESTAMP, server_default=func.now())
#     updated_at: Mapped[dt.datetime] = mapped_column(
#         TIMESTAMP, server_default=func.now(), onupdate=func.now()
#     )
#
