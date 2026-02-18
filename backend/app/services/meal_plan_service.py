from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.models.sql_models import MealPlan, User
# from app.ai.ai_meal_planner import GeminiMealPlanner
from app.services.ai_meal_planner import GeminiMealPlanner
from app.core.config import settings


class MealPlanService:
    """
    Service responsible for:
    - Generating AI meal plans using Gemini
    - Persisting meal plans in DB
    - Normalizing AI output into DB-friendly format
    """

    def __init__(self, db: Session):
        self.db = db
        self.ai = GeminiMealPlanner(
            api_key=settings.GEMINI_API_KEY
        )

    # ---------------------------------------------------------
    # Public API
    # ---------------------------------------------------------

    def generate_for_user(self, user_id: str, days: int) -> dict[str, Any]:
        """
        Generate a personalized meal plan for the given user
        using ONLY DB-stored user preferences.

        Frontend only provides:
        - number of days
        """

        if days < 1 or days > 14:
            raise ValueError("Meal plan days must be between 1 and 14")

        user = self._get_user(user_id)
        summary = self._get_onboarding_summary(user)

        # Extract required nutrition data safely
        daily_calories = summary["daily_calories"]
        macros = summary["macro_targets"]

        user_profile = {
            "goal": summary.get("goal", "maintain"),
            "meals_per_day": summary.get(
                "meals_per_day", ["breakfast", "lunch", "dinner"]
            ),
            "dietary_restrictions": summary.get("dietary_restrictions", []),
            "allergies": summary.get("allergies", []),
            "cuisine_preferences": summary.get("cuisine_preferences", []),
        }

        # ---------------- AI generation ----------------
        ai_plan = self.ai.generate_meal_plan(
            user_profile=user_profile,
            days=days,
            target_calories=daily_calories,
            macros=macros,
        )

        # ---------------- Persist ----------------
        start_date = date.today()
        end_date = start_date + timedelta(days=days - 1)

        normalized_days = self._normalize_ai_days(
            start_date=start_date,
            ai_days=ai_plan,
        )

        plan = MealPlan(
            plan_id=uuid.uuid4().hex,
            user_id=user_id,
            start_date=start_date,
            end_date=end_date,
            days=normalized_days,
        )

        self.db.add(plan)
        self.db.commit()
        self.db.refresh(plan)

        return self._plan_to_dict(plan)

    # ---------------------------------------------------------
    # Helpers
    # ---------------------------------------------------------

    def _get_user(self, user_id: str) -> User:
        user = (
            self.db.query(User)
            .filter(User.user_id == user_id)
            .first()
        )
        if not user:
            raise ValueError("User not found")
        return user

    def _get_onboarding_summary(self, user: User) -> dict[str, Any]:
        """
        Ensures onboarding summary exists and is valid.
        Fixes all `None.get()` related crashes.
        """
        summary = user.onboarding_summary

        if not isinstance(summary, dict):
            raise ValueError("User onboarding not completed")

        if "daily_calories" not in summary:
            raise ValueError("Daily calorie target missing")

        if "macro_targets" not in summary:
            raise ValueError("Macro targets missing")

        return summary

    def _normalize_ai_days(
        self,
        start_date: date,
        ai_days: dict[str, Any],
    ) -> dict[str, Any]:
        """
        Converts AI format:
            day_1, day_2, ...
        into DB format:
            YYYY-MM-DD -> meals
        """

        normalized: dict[str, Any] = {}

        # Ensure deterministic order
        sorted_days = sorted(
            ai_days.items(),
            key=lambda x: int(x[0].replace("day_", ""))
        )

        for index, (_, meals) in enumerate(sorted_days):
            day_date = start_date + timedelta(days=index)
            normalized[day_date.isoformat()] = meals

        return normalized

    def _plan_to_dict(self, plan: MealPlan) -> dict[str, Any]:
        """
        Convert MealPlan ORM → API response
        """
        return {
            "plan_id": plan.plan_id,
            "start_date": plan.start_date.isoformat(),
            "end_date": plan.end_date.isoformat(),
            "days": plan.days,
            "created_at": (
                plan.created_at.isoformat()
                if plan.created_at else None
            ),
            "updated_at": (
                plan.updated_at.isoformat()
                if plan.updated_at else None
            ),
        }

    def get_all_meal_plans(self, user_id: str) -> dict:
        plans = (
            self.db.query(MealPlan)
            .filter(MealPlan.user_id == user_id)
            .order_by(desc(MealPlan.created_at))
            .all()
        )

        return {
            "meal_plans": [
                {
                    "plan_id": plan.plan_id,
                    "start_date": plan.start_date.isoformat(),
                    "end_date": plan.end_date.isoformat(),
                    "days_count": len(plan.days) if plan.days else 0,
                    "created_at": plan.created_at.isoformat(),
                }
                for plan in plans
            ]
        }

    def get_meal_plan_by_id(self, user_id: str, plan_id: str) -> dict:
        plan = (
            self.db.query(MealPlan)
            .filter(
                MealPlan.plan_id == plan_id,
                MealPlan.user_id == user_id,
            )
            .first()
        )

        if not plan:
            raise HTTPException(status_code=404, detail="Meal plan not found")

        return {
            "plan_id": plan.plan_id,
            "start_date": plan.start_date.isoformat(),
            "end_date": plan.end_date.isoformat(),
            "days": plan.days or {},
            "created_at": plan.created_at.isoformat(),
            "updated_at": plan.updated_at.isoformat(),
        }
