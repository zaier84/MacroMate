from datetime import datetime
from typing import Any, Tuple
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

import uuid

from app.models.sql_models import User, UserOnboarding, WeightEntry
from app.services.user_service import publish_event
from app.services.nutrition_utils import (
    calculate_calories_and_macros,
    _lbs_to_kg,
    _ftin_to_cm,
)

def _generate_id() -> str:
    return uuid.uuid4().hex # 32 char hex id

RATE_PRESETS = {
    # magnitudes in kg/week (positive magnitude)
    "conservative": 0.25,   # safe small change
    "standard":     0.5,    # commonly recommended
    "aggressive":   0.75,   # more aggressive — UI should warn
}

# Allowed ranges (magnitudes) — server validates custom values against these
ALLOWED_RANGES = {
    "lose":  (0.1, 1.0),   # allow 0.1 - 1.0 kg/week for loss (magnitudes)
    "gain":  (0.05, 0.75), # allow 0.05 - 0.75 kg/week for gain
}

def _normalize_goal_type(goal_type: str | None) -> str:
    if not goal_type:
        return ""
    g = goal_type.lower()

    if "lose" in g or "loss" in g or "weight_loss" in g:
        return "loss"
    if "gain" in g or "muscle" in g:
        return "gain"
    if "maintain" in g or "maintain" in g or "maintainance" in g:
        return "maintain"

    return g

def _resolve_weekly_goal_from_goals(goals: dict) -> Tuple[float | None, dict]:
    """
    Returns (weekly_goal_kg_per_week, meta)
    weekly_goal: float (positive = gain, negative = loss) or None if not provided.
    meta: debug info e.g. {"source":"preset","preset":"standard"}
    """
    meta = {}

    # 1) backwards compatibility: if weekly_goal supplied directly, use it
    if "weekly_goal" in goals and goals["weekly_goal"] is not None:
        try:
            val = float(goals["weekly_goal"])
            meta["source"] = "explicit_weekly_goal"
            return val, meta
        except Exception:
            raise ValueError("Invalid numeric weekly_goal provided")

    # 2) prefer explicit numeric fields target / target_weight etc are separate.
    # 3) parse rate_option / custom_rate (new UI)
    goal_type_raw = goals.get("goal_type") or goals.get("primary_goal") or ""
    goal_norm = _normalize_goal_type(goal_type_raw)

    # If user wants to maintain weight
    if goal_norm == "maintain" or (goal_type_raw and "maintain" in goal_type_raw.lower()):
        meta["source"] = "maintain"
        return 0.0, meta

    # Look for a preset selection (e.g. "standard", "conservative", "aggressive")
    rate_choice = goals.get("rate_option") or goals.get("rate_choice") or goals.get("progress_rate")
    custom_rate = goals.get("custom_rate_kg_per_week") or goals.get("custom_rate") or goals.get("rate_custom")

    if rate_choice:
        rate_choice = str(rate_choice).lower()
        if rate_choice in RATE_PRESETS:
            magnitude = float(RATE_PRESETS[rate_choice])
            meta["source"] = "preset"
            meta["preset"] = rate_choice
        elif rate_choice == "custom":
            if custom_rate is None:
                raise ValueError("Custom rate selected but no custom_rate_kg_per_week provided")
            try:
                magnitude = float(custom_rate)
                meta["source"] = "custom"
            except Exception:
                raise ValueError("Invalid custom_rate_kg_per_week value")
        else:
            # unknown rate_choice — try parsing as numeric
            try:
                magnitude = float(rate_choice)
                meta["source"] = "raw_numeric_choice"
            except Exception:
                raise ValueError(f"Unknown rate_option: {rate_choice}")
    elif custom_rate is not None:
        try:
            magnitude = float(custom_rate)
            meta["source"] = "custom"
        except Exception:
            raise ValueError("Invalid custom_rate_kg_per_week value")
    else:
        # no rate provided — maybe old client: check weekly_goal fallback above already
        return None, meta

    # magnitude must be positive; sign depends on goal_type
    if goal_norm == "lose":
        direction = -1
        min_m, max_m = ALLOWED_RANGES["lose"]
    elif goal_norm == "gain":
        direction = 1
        min_m, max_m = ALLOWED_RANGES["gain"]
    else:
        # unknown goal type — we cannot infer sign. If magnitude == 0 -> ok.
        direction = 0
        min_m, max_m = (0.0, 1.0)

    if magnitude < 0:
        magnitude = abs(magnitude)  # user might send negative; treat magnitude

    # Validate bounds
    if direction != 0:
        if not (min_m <= magnitude <= max_m):
            raise ValueError(
                f"Selected rate {magnitude} kg/week is outside allowed range for '{goal_norm}' "
                f"({min_m} to {max_m} kg/week)."
            )

    weekly_goal_value = 0.0 if direction == 0 else (direction * magnitude)
    meta["magnitude"] = magnitude
    meta["weekly_goal_value"] = weekly_goal_value

    return weekly_goal_value, meta

class OnboardingService:
    def __init__(self, db: Session):
        self.db = db

    def get_or_create_onboarding(self, user_id: str) -> UserOnboarding:
        rec = self.db.query(UserOnboarding).filter(UserOnboarding.user_id == user_id).first()
        if rec:
            return rec
        rec = UserOnboarding(
            user_onboarding_id = _generate_id(),
            user_id=user_id,
            current_step="personal_info",
            progress={},
            is_complete=False
        )
        self.db.add(rec)
        self.db.commit()
        self.db.refresh(rec)
        return rec

    def get_progress(self, user_id: str) -> dict[str, Any]:
        rec = self.get_or_create_onboarding(user_id)
        return {
            "current_step": rec.current_step,
            "progress": rec.progress or {},
            "is_complete": bool(rec.is_complete),
        }

    def save_step(self, user_id: str, step_name: str, payload: dict) -> dict[str, Any]:
        rec = self.get_or_create_onboarding(user_id)
        progress: dict = rec.progress or {}

        progress[step_name] = payload
        rec.progress = progress
        rec.current_step = step_name
        rec.updated_at = datetime.utcnow()
        try:
            self.db.add(rec)
            self.db.commit()
            self.db.refresh(rec)
        except SQLAlchemyError:
            self.db.rollback()
            raise

        # Publish an event so projection service updates Mongo quickly
        publish_event("UserOnboardingStepSaved", {
            "user_id": user_id,
            "step": step_name,
            "payload": payload,
            "timestamp": datetime.utcnow().isoformat()
        })

        return {"ok": True, "step": step_name}

    def complete_onboarding(self, user_id: str) -> dict[str, Any]:
        rec = self.get_or_create_onboarding(user_id)
        progress = rec.progress or {}

        # 1. Minimal required steps
        required = ["personal_info", "body_metrics", "goals"]
        missing = [r for r in required if r not in progress]
        if missing:
            raise ValueError(f"Missing required onboarding steps: {missing}")

        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise ValueError("User not found")

        # 2. Extract step data
        personal = progress.get("personal_info", {}) or {}
        body = progress.get("body_metrics", {}) or {}
        dietary = progress.get("dietary_preferences", {}) or {}
        meal_prefs = progress.get("meal_preferences", {}) or {}
        goals = progress.get("goals", {}) or {}
        units_raw = progress.get("unit_preferences", {}) or {}
        macro_distribution = progress.get("macro_distribution", {}) or {}
        lifestyle = progress.get("lifestyle", {}) or {}

        # ------------------------------
        # Units handling (same as before)
        # ------------------------------
        units_pref: dict[str, str] = {
            "height": "cm",
            "weight": "kg",
        }
        if "units" in units_raw:
            raw_units = units_raw["units"]
            if isinstance(raw_units, dict):
                if raw_units.get("height") in {"cm", "ft_in"}:
                    units_pref["height"] = raw_units["height"]
                if raw_units.get("weight") in {"kg", "lb", "lbs"}:
                    units_pref["weight"] = "lb" if raw_units["weight"] in {"lb", "lbs"} else "kg"

        # ------------------------------
        # Core user profile
        # ------------------------------
        if personal.get("full_name"):
            user.name = personal["full_name"]
        if personal.get("email"):
            user.email = personal["email"]
        if personal.get("date_of_birth"):
            try:
                user.dob = personal["date_of_birth"]
            except Exception:
                pass
        if personal.get("gender"):
            user.gender = personal["gender"]

        # ------------------------------
        # Body metrics (normalize)
        # ------------------------------
        if "height_cm" in body:
            user.height_cm = int(body["height_cm"])
        else:
            ft, inch = body.get("height_ft"), body.get("height_in")
            cm = _ftin_to_cm(ft, inch)
            if cm:
                user.height_cm = cm
            units_pref["height"] = "ft_in"

        summary = user.onboarding_summary or {}
        if "weight_kg" in body:
            summary["starting_weight_kg"] = float(body["weight_kg"])
        elif "weight_lbs" in body:
            summary["starting_weight_kg"] = _lbs_to_kg(body["weight_lbs"])
            units_pref["weight"] = "lb"
        elif "weight" in body:
            val = body["weight"]
            if units_pref["weight"] == "lb":
                summary["starting_weight_kg"] = _lbs_to_kg(val)
            else:
                summary["starting_weight_kg"] = float(val)

        # store age & gender in summary too
        if body.get("age"):
            summary["age"] = int(body["age"])
        if body.get("gender"):
            summary["gender"] = body["gender"]

        user.onboarding_summary = summary

        # ------------------------------
        # Goals + progress rate mapping
        # ------------------------------
        # Try to resolve weekly_goal from 'goals' payload or presets/customs
        weekly_goal_value = None
        try:
            weekly_goal_value, meta = _resolve_weekly_goal_from_goals(goals)
        except ValueError:
            # bubble up validation errors so the API returns 400
            raise

        # If resolve returned a numeric weekly goal, store it in summary
        if weekly_goal_value is not None:
            summary["weekly_goal"] = weekly_goal_value
            user.onboarding_summary = summary
        # also preserve target weight if provided
        if goals.get("target_weight_kg"):
            summary["target_weight_kg"] = goals["target_weight_kg"]
        elif goals.get("target_weight_lbs"):
            summary["target_weight_kg"] = _lbs_to_kg(goals["target_weight_lbs"])

        # Set user.goal string (keep previous logic)
        if goals.get("goal_type") or goals.get("primary_goal"):
            user.goal = goals.get("goal_type") or goals.get("primary_goal")

        # if "metabolic_adjustment_kcal" not in summary:
        #     summary["metabolic_adjustment_kcal"] = 0.0
        existing_adj = (user.onboarding_summary or {}).get("metabolic_adjustment_kcal", 0.0)
        summary["metabolic_adjustment_kcal"] = existing_adj
        user.onboarding_summary = summary

        # ------------------------------
        # Preferences (unchanged)
        # ------------------------------
        prefs = user.preferences or {}
        prefs["units"] = units_pref
        if dietary:
            prefs["diet_type"] = dietary.get("diet_type")
            prefs["allergies"] = dietary.get("allergies", [])
            prefs["exclude_foods"] = dietary.get("exclude_foods", [])
        if meal_prefs:
            prefs["meals_per_day"] = meal_prefs.get("meals_per_day")
            prefs["preferred_meal_times"] = meal_prefs.get("preferred_meal_times", [])
        if lifestyle:
            prefs["lifestyle"] = lifestyle
        if macro_distribution:
            prefs["macro_distribution"] = macro_distribution

        user.preferences = prefs

        # ------------------------------
        #  Calorie & macro calculation
        # ------------------------------
        try:
            age_val = personal.get("age") or body.get("age")
            weight_val = summary.get("starting_weight_kg")
            height_val = user.height_cm
            gender_val = personal.get("gender") or user.gender
            activity_val = lifestyle.get("activity_level") or goals.get("activity_level")
            weekly_goal_val = summary.get("weekly_goal")

            # NOTE: calculate_calories_and_macros will use weekly_goal sign properly
            # from app.services.nutrition_service import calculate_calories_and_macros
            daily_calories, macro_targets = calculate_calories_and_macros(
                weight_kg=weight_val,
                height_cm=height_val,
                age=age_val,
                gender=gender_val,
                activity_level=activity_val,
                goal_type=user.goal,
                weekly_goal=weekly_goal_val,
                macro_distribution=macro_distribution,
            )

            summary["daily_calories"] = daily_calories
            summary["macro_targets"] = macro_targets
            user.onboarding_summary = summary

        except Exception:
            import logging
            logging.getLogger(__name__).exception("Calorie/macros calculation failed")

        # ------------------------------
        # Finalize
        # ------------------------------
        user.is_profile_complete = True
        user.updated_at = datetime.utcnow()
        rec.is_complete = True
        rec.updated_at = datetime.utcnow()

        try:
            self.db.add(user)
            self.db.add(rec)
            self.db.commit()
            self.db.refresh(user)
            self.db.refresh(rec)
        except SQLAlchemyError:
            self.db.rollback()
            raise

        # publish event for projection / recommender
        publish_event("OnboardingCompleted", {
            "user_id": user_id,
            "timestamp": datetime.utcnow().isoformat(),
            "summary": rec.progress
        })

        return {
            "ok": True,
            "user_id": user.user_id,
            "is_profile_complete": bool(user.is_profile_complete),
            "completed_at": datetime.utcnow().isoformat(),
            "units": prefs.get("units"),
            "daily_calories": summary.get("daily_calories"),
            "macro_targets": summary.get("macro_targets"),
            "weekly_goal": summary.get("weekly_goal", None),
            "weekly_goal_meta": meta if 'meta' in locals() else {}
        }

    def get_onboarding_summary(self, user_id: str) -> dict[str, Any]:
        """
        Build the payload for the onboarding summary screen using:
         - user.onboarding_summary (daily_calories, macro_targets, starting_weight_kg, weekly_goal, etc.)
         - user.preferences (units, meal_preferences, diet_type, etc.)
         - latest weight entry (if present) to use as current weight
         - computed BMI and BMI category
        """

        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise ValueError("User not found")

        # ensure we have the freshest JSON mapping
        summary = dict(user.onboarding_summary or {})
        prefs = dict(user.preferences or {})

        # determine current weight: prefer latest weight entry; else use starting_weight_kg
        latest_weight_row = (
            self.db.query(WeightEntry)
            .filter(WeightEntry.user_id == user_id)
            .order_by(WeightEntry.date.desc())
            .first()
        )
        if latest_weight_row:
            current_weight_kg = float(latest_weight_row.weight_kg)
        else:
            current_weight_kg = summary.get("starting_weight_kg")

        # height: prefer user.height_cm, else summary height_cm
        height_cm = getattr(user, "height_cm", None) or summary.get("height_cm") or summary.get("height")

        # age: prefer summary age, else compute from dob if present
        age = summary.get("age")
        if age is None and getattr(user, "dob", None):
            try:
                dob = user.dob
                today = datetime.utcnow().date()
                if (dob):
                    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
            except Exception:
                age = None

        # BMI calculation
        bmi = None
        bmi_category = None
        try:
            if current_weight_kg is not None and height_cm:
                h_m = float(height_cm) / 100.0
                if h_m > 0:
                    bmi_val = float(current_weight_kg) / (h_m * h_m)
                    bmi = round(bmi_val, 2)
                    # BMI categories (simple)
                    if bmi_val < 18.5:
                        bmi_category = "Underweight"
                    elif bmi_val < 25:
                        bmi_category = "Normal"
                    elif bmi_val < 30:
                        bmi_category = "Overweight"
                    else:
                        bmi_category = "Obese"
        except Exception:
            bmi = None
            bmi_category = None

        # Goal / weekly goal
        primary_goal = summary.get("goal_type") or summary.get("primary_goal") or user.goal
        target_weight = summary.get("target_weight_kg") or None
        activity_level = None
        lifestyle = prefs.get("lifestyle") or {}
        if isinstance(lifestyle, dict):
            activity_level = lifestyle.get("activity_level")
        if not activity_level:
            activity_level = prefs.get("activity_level")

        # Daily calories & macros
        daily_calories = summary.get("daily_calories")
        macro_targets = summary.get("macro_targets") or {}

        # Tracking metrics simple heuristic: count enabled trackers
        metrics_count = 0
        # weight tracking considered "enabled" if we have >=1 weight entry OR starting_weight exists
        if latest_weight_row or summary.get("starting_weight_kg"):
            metrics_count += 1
        if prefs.get("meals_per_day"):
            metrics_count += 1
        if prefs.get("diet_type") or prefs.get("exclude_foods"):
            metrics_count += 1
        # workout tracking: if workout sessions exist (quick count)
        try:
            # count rows in workout_sessions if table/model exists
            from app.models.sql_models import WorkoutSession
            ws_count = self.db.query(WorkoutSession).filter(WorkoutSession.user_id == user_id).count()
            if ws_count:
                metrics_count += 1
        except Exception:
            # ignore if workouts not present
            pass

        # units
        units = prefs.get("units") or {}

        # meals per day
        meals_per_day = prefs.get("meals_per_day") or (prefs.get("meal_preferences") or {}).get("meals_per_day")

        # diet type
        diet_type = prefs.get("diet_type") or prefs.get("diet") or (prefs.get("dietary_preferences") or {}).get("diet_type")

        result = {
            "profile": {
                "name": user.name or (summary.get("full_name") or summary.get("name")),
                "age": age,
                "current_weight_kg": float(current_weight_kg) if current_weight_kg is not None else None,
                "height_cm": int(height_cm) if height_cm is not None else None,
                "bmi": bmi,
                "bmi_category": bmi_category,
            },
            "goal": {
                "primary_goal": primary_goal,
                "target_weight_kg": float(target_weight) if target_weight is not None else None,
                "activity_level": activity_level,
            },
            "daily_targets": {
                "daily_calories": int(daily_calories) if daily_calories is not None else None,
                "macro_targets": macro_targets,
            },
            "tracking": {
                "metrics_count": metrics_count,
                "meals_per_day": meals_per_day,
                "diet_type": diet_type,
                "units": units,
            },
            "raw_onboarding_summary": summary,  # optional; useful for debugging / frontend flexibility
        }

        return result
