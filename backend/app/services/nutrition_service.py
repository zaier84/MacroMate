from typing import Any
from math import floor

from sqlalchemy.orm import Session

from app.models.sql_models import User, UserOnboarding
from app.services.nutrition_utils import (
    calculate_calories_and_macros,
    _safe_int,
    _safe_float,
    _lbs_to_kg,
    _age_from_dob,
)

def _macros_from_percentages(calories: int, protein_pct: int, carbs_pct: int, fat_pct: int) -> dict[str, int]:
    # grams: protein & carbs = 4 kcal/g, fat = 9 kcal/g
    protein_g = floor((calories * protein_pct / 100.0) / 4.0)
    carbs_g = floor((calories * carbs_pct / 100.0) / 4.0)
    fats_g = floor((calories * fat_pct / 100.0) / 9.0)
    return {
        "protein_g": int(protein_g),
        "carbs_g": int(carbs_g),
        "fats_g": int(fats_g),
        "protein_pct": int(protein_pct),
        "carbs_pct": int(carbs_pct),
        "fat_pct": int(fat_pct),
    }

class NutritionService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def _get_user(self, user_id: str) -> User | None:
        return self.db.query(User).filter(User.user_id == user_id).first()

    def get_daily_nutrition(self, user_id: str) -> dict[str, Any]:
        """
        Returns a merged view:
        {
          "base": {"calories":..., "macro_targets": {...}},
          "adjusted": {"calories":..., "macro_targets": {...}},
          "metabolic_adjustment_kcal": <number>,
          "weekly_goal": <number or None>
        }
        """

        user = self._get_user(user_id)
        if not user:
            raise ValueError("User not found")

        self.db.refresh(user)
        # base summary/prefs from stored user record
        summary = dict(user.onboarding_summary or {})
        prefs = dict(user.preferences or {})
        print(summary)

        # If there's an in-progress onboarding, let it override values live
        onboarding: UserOnboarding | None = (
            self.db.query(UserOnboarding)
            .filter(UserOnboarding.user_id == user_id)
            .first()
        )
        if onboarding and onboarding.progress:
            prog = onboarding.progress or {}
            # body metrics
            body = prog.get("body_metrics") or {}
            if body.get("age") is not None:
                summary["age"] = int(body["age"])
            if body.get("gender"):
                summary["gender"] = body["gender"]
            # height override
            if "height_cm" in body:
                try:
                    summary["height_cm"] = int(body["height_cm"])
                except Exception:
                    pass
            elif "height_ft" in body or "height_in" in body:
                # prefer ft/in if present, but we don't mutate DB - compute later
                pass

            # weight override
            if "weight_kg" in body:
                summary["starting_weight_kg"] = float(body["weight_kg"])
            elif "weight_lbs" in body:
                summary["starting_weight_kg"] = _lbs_to_kg(body.get("weight_lbs"))
            elif "weight" in body:
                # ambiguous units — interpret later using prefs
                summary["weight"] = body.get("weight")

            # goals override
            goals = prog.get("goals") or {}
            if "weekly_goal" in goals:
                try:
                    summary["weekly_goal"] = float(goals["weekly_goal"])
                except Exception:
                    pass
            if "goal_type" in goals:
                summary.setdefault("goal_type", goals.get("goal_type"))
                summary.setdefault("primary_goal", goals.get("goal_type"))

            # macro/lifestyle overrides
            if "macro_distribution" in prog:
                prefs["macro_distribution"] = prog.get("macro_distribution")
            if "lifestyle" in prog:
                prefs["lifestyle"] = prog.get("lifestyle")
            elif "activity_level" in prog:
                prefs.setdefault("lifestyle", {})["activity_level"] = prog.get("activity_level")

            # unit prefs
            if "unit_preferences" in prog:
                up = prog.get("unit_preferences")
                if isinstance(up, dict):
                    if "units" in up and isinstance(up["units"], dict):
                        prefs["units"] = up["units"]
                    else:
                        prefs.setdefault("units", {}).update(up)

        # Determine final inputs for calorie calculation
        # Age: prefer summary['age'] else compute from dob
        age_val = summary.get("age")
        if age_val is None and getattr(user, "dob", None):
            try:
                age_val = _age_from_dob(user.dob)
            except Exception:
                age_val = None

        # Weight: prefer starting_weight_kg else attempt to interpret 'weight' with prefs
        weight_val = summary.get("starting_weight_kg")
        if weight_val is None and "weight" in summary:
            w_raw = summary.get("weight")
            units_map = prefs.get("units", {})
            weight_unit = None
            if isinstance(units_map, dict):
                weight_unit = units_map.get("weight")
            try:
                if weight_unit and str(weight_unit).lower().startswith("lb"):
                    weight_val = _lbs_to_kg(w_raw)
                else:
                    weight_val = _safe_float(w_raw)
            except Exception:
                weight_val = None

        # Height: prefer stored user.height_cm, else summary/overrides
        height_val = user.height_cm if getattr(user, "height_cm", None) else None
        if not height_val:
            if "height_cm" in summary:
                height_val = _safe_int(summary.get("height_cm"))
            # else if ft/in override exists in summary, you would convert here (omitted for brevity)

        # Gender preference
        gender_val = summary.get("gender") or user.gender

        # Activity level
        activity_val = None
        lifestyle = prefs.get("lifestyle")
        if lifestyle and isinstance(lifestyle, dict):
            activity_val = lifestyle.get("activity_level")
        if not activity_val:
            activity_val = prefs.get("activity_level")

        # Goal type and weekly_goal
        goal_type_val = summary.get("goal_type") or summary.get("primary_goal") or user.goal
        weekly_goal_val = summary.get("weekly_goal")

        # Macro distribution used by calculator
        macro_dist = prefs.get("macro_distribution") or summary.get("macro_distribution")

        # compute base calories/macros (from onboarding summary and prefs)
        try:
            base_calories, base_macros = calculate_calories_and_macros(
                weight_kg=weight_val,
                height_cm=height_val,
                age=age_val,
                gender=gender_val,
                activity_level=activity_val,
                goal_type=goal_type_val,
                weekly_goal=weekly_goal_val,
                macro_distribution=macro_dist,
            )
        except ValueError as e:
            # bubble up missing-data information to caller
            raise ValueError(str(e))

        metabolic_adj = 0.0
        try:
            metabolic_adj = float(summary.get("metabolic_adjustment_kcal", 0.0) or 0.0)
        except Exception:
            metabolic_adj = 0.0

        # Apply adjustment: adjusted_calories = base + metabolic_adj (clamp to reasonable min)
        adjusted_calories = max(1200, int(round(base_calories + metabolic_adj)))

        # Recompute adjusted macro grams using base percentage distribution (keep %s consistent)
        protein_pct = int(base_macros.get("protein_pct", base_macros.get("protein", 30)))
        carbs_pct = int(base_macros.get("carbs_pct", base_macros.get("carbs", 50)))
        fat_pct = int(base_macros.get("fat_pct", base_macros.get("fat", 20)))
        adjusted_macros = _macros_from_percentages(adjusted_calories, protein_pct, carbs_pct, fat_pct)

        return {
            "base": {"calories": int(base_calories), "macro_targets": base_macros},
            "adjusted": {"calories": int(adjusted_calories), "macro_targets": adjusted_macros},
            "metabolic_adjustment_kcal": float(round(metabolic_adj, 1)),
            "weekly_goal": weekly_goal_val,
        }

